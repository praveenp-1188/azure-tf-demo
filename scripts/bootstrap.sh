#!/usr/bin/env bash
# One-time setup: Terraform state storage + GitHub OIDC identity (no client secrets).
# Usage: ./scripts/bootstrap.sh <github-owner>/<repo>
set -euo pipefail

REPO="${1:?usage: bootstrap.sh <owner>/<repo>}"
LOCATION="northeurope"
STATE_RG="rg-tfstate"
STATE_SA="sttfstate$RANDOM$RANDOM"
APP_NAME="gh-oidc-azure-tf-demo"

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "==> State storage"
az group create -n "$STATE_RG" -l "$LOCATION" -o none
az storage account create -n "$STATE_SA" -g "$STATE_RG" -l "$LOCATION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
az storage container create -n tfstate --account-name "$STATE_SA" --auth-mode login -o none

echo "==> Entra app + service principal for GitHub Actions"
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID" -o none || true

# Federated credentials: main branch (apply), pull requests (plan), dev environment (apply job)
for SUBJECT in "repo:${REPO}:ref:refs/heads/main" "repo:${REPO}:pull_request" "repo:${REPO}:environment:dev"; do
  NAME=$(echo "$SUBJECT" | tr ':/' '--' | cut -c1-120)
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${NAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUBJECT}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" -o none
done

echo "==> Role assignments"
# Contributor to create resources; User Access Administrator is NOT needed for this demo.
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/$SUB_ID" -o none
# Data-plane access to the state container (backend uses Entra ID auth, no storage keys).
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n "$STATE_SA" -g "$STATE_RG" --query id -o tsv)" -o none

cat <<EOF

Add these as GitHub repository secrets (Settings > Secrets and variables > Actions):
  AZURE_CLIENT_ID        = $APP_ID
  AZURE_TENANT_ID        = $TENANT_ID
  AZURE_SUBSCRIPTION_ID  = $SUB_ID
  TF_STATE_RG            = $STATE_RG
  TF_STATE_SA            = $STATE_SA
  ALERT_EMAIL            = <your email>

Also give yourself 'Storage Blob Data Contributor' on $STATE_SA for local runs.
EOF
