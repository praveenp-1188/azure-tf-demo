# azure-tf-demo

A small, end-to-end example of Terraform on Azure using only free or near-free services:

- **Reusable code** – two local modules (`monitoring`, `webapp`) consumed by an environment (`envs/dev`)
- **CI/CD** – GitHub Actions: fmt/validate/tflint → plan (commented on PRs) → approved apply → app deploy → smoke test
- **Auth** – GitHub OIDC federation to Entra ID; no client secrets, no storage keys
- **Observability** – Log Analytics, workspace-based Application Insights (codeless agent), diagnostic settings, action group, optional 5xx alert, and a budget alert

```
.
├── modules/
│   ├── monitoring/        # Log Analytics + App Insights + email action group
│   └── webapp/            # F1 Linux App Service + diagnostics + optional alert
├── envs/dev/              # Composes the modules, adds RG + budget
├── app/                   # Tiny Node.js app (/, /health, /error)
├── scripts/bootstrap.sh   # One-time: state storage + OIDC app registration
└── .github/workflows/     # terraform.yml (plan/apply/deploy), destroy.yml
```

## What it costs

| Resource | Tier | Cost |
|---|---|---|
| App Service Plan | F1 (Free) | €0 |
| Log Analytics + App Insights | Pay-as-you-go, 0.1 GB/day cap | €0 within the 5 GB/month free grant |
| Action group (email) | – | €0 (1,000 emails/month free) |
| Budget | – | €0 |
| State storage account | Standard LRS | a few cents/month |
| Metric alert (`enable_metric_alert = true`) | – | ~$0.10/month, off by default |

F1 limits: 60 CPU-minutes/day, no Always On, no deployment slots, cold starts. Fine for a demo.

## Setup

1. **Push this folder to a new GitHub repo.**

2. **Bootstrap** (needs `az login` with Owner or Contributor + User Access Administrator on the subscription, and rights to create app registrations):
   ```bash
   chmod +x scripts/bootstrap.sh
   ./scripts/bootstrap.sh <github-owner>/<repo>
   ```

3. **Add the repo secrets** the script prints: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TF_STATE_RG`, `TF_STATE_SA`, `ALERT_EMAIL`.

4. **Create a GitHub environment** named `dev` (Settings → Environments). Add yourself as a required reviewer if you want a manual gate before apply.

5. **Open a PR** touching `envs/` or `modules/` → the plan appears as a PR comment. **Merge** → apply runs, the app deploys, and `/health` is smoke-tested.

## Running locally

```bash
cd envs/dev
cp backend.hcl.example backend.hcl   # fill in the storage account name
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init -backend-config=backend.hcl
terraform plan
```

## Seeing the observability

- Hit `https://<app>/` a few times and `https://<app>/error` to generate failures.
- **Application Insights → Live Metrics / Failures / Transaction search**: requests, exceptions and console logs, collected by the codeless agent.
- **Log Analytics → Logs**, for example:
  ```kusto
  AppServiceHTTPLogs
  | where TimeGenerated > ago(1h)
  | summarize count() by ScStatus, bin(TimeGenerated, 5m)
  ```
  ```kusto
  AppRequests
  | summarize avg(DurationMs), failures = countif(Success == false) by bin(TimeGenerated, 5m)
  ```
- Set `enable_metric_alert = true` and hit `/error` 6+ times in 5 minutes to receive the alert email.

## Extending

- **Another environment:** copy `envs/dev` to `envs/prod`, change `terraform.tfvars` and the state `key`, and add a matrix or second job in the workflow.
- **Reuse modules across repos:** move `modules/*` to their own repo and reference them with `source = "git::https://github.com/<you>/tf-modules.git//webapp?ref=v1.0.0"`.

## Teardown

Run the **terraform-destroy** workflow (type `destroy`), then delete `rg-tfstate` and the `gh-oidc-azure-tf-demo` app registration if you're done.
