// Minimal Node app. Application Insights auto-instrumentation (set via app settings)
// captures requests, dependencies, exceptions and console output without code changes.
const http = require("http");

const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ status: "ok" }));
  }

  if (req.url === "/error") {
    // Handy for testing the 5xx alert and failures blade in App Insights
    console.error("Simulated failure");
    res.writeHead(500);
    return res.end("boom");
  }

  console.log(`Request: ${req.method} ${req.url}`);
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello from Terraform + GitHub Actions on Azure Free tier\n");
});

server.listen(port, () => console.log(`Listening on ${port}`));
