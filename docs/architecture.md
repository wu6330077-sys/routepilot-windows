# Architecture

RoutePilot separates human-readable configuration, generated routing policy, operating-system integration, and optional process supervision.

## Components

1. `config/routepilot.local.json` defines two loopback HTTP proxies and domain groups.
2. `New-RoutePilotPac.ps1` validates that configuration and generates `runtime/routepilot.pac`.
3. `Install-EdgeRouting.ps1` embeds the PAC bytes in a user-level Microsoft Edge policy and saves the previous value under ignored local state.
4. `RoutePilotService.cs` is an optional generic process supervisor. The installer configures it to run a Hysteria 2 client as `LocalService`.
5. `Test-RoutePilotHealth.ps1` verifies local ports, service state, Edge policy integrity, certificate lifetime, and an optional expected bulk-route exit.

## Routing invariants

- Local and private-network hosts are direct.
- Protected domains use the primary proxy with no fallback.
- Bulk domains use the bulk proxy with no cross-route fallback.
- Other domains use the primary proxy and may optionally fall back to direct according to local configuration.
- A domain may not appear in both protected and bulk groups.

## Data boundaries

Tracked files contain source, documentation, tests, and placeholders only. Generated PAC files, policy backups, logs, binaries, local configuration, credentials, certificates, and reports are ignored.
