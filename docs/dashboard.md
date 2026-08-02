# RoutePilot route-test dashboard

The dashboard is a neutral local test tool. It presents measurements and policy state without classifying the result as a success or failure.

## Open it

Start both local HTTP proxies and double-click `Open-Dashboard.cmd`. No Node.js, Python, or browser extension is required.

Opening the dashboard reads the current user's Edge `ProxySettings`, identifies an embedded RoutePilot PAC, and checks TCP connectivity to both configured local HTTP proxies. It does not change the registry, switch nodes, enable TUN, or download a test object.

## Benchmark behavior

After you click the benchmark button, the dashboard requests the same Cloudflare object through each HTTP proxy. The default uses two 5 MB transfers per route, or about 20 MB total. It displays each route's median Mbps and the factual bulk-to-primary ratio.

The measurement describes the two proxy paths to one test endpoint. It is not a guaranteed speed for a specific website, and it does not by itself prove which public exit a website request used. Congestion, provider limits, VPS capacity, distance, loss, and the test time can all change the result.

## Command-line snapshots

Read local state without downloading a test object:

```powershell
.\scripts\Get-RoutePilotSnapshot.ps1 -SkipBenchmark -AsJson
```

Run the default comparison and return JSON:

```powershell
.\scripts\Get-RoutePilotSnapshot.ps1 -AsJson
```
