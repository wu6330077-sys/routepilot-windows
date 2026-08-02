# Architecture

RoutePilot separates human-readable configuration, generated routing policy, operating-system integration, and optional process supervision.

## Components

1. `Setup-RoutePilot.ps1` turns the practical preset and beginner choices into an ignored local configuration.
2. `config/routepilot.local.json` defines two loopback HTTP proxies and domain groups.
3. `New-RoutePilotPac.ps1` validates that configuration and generates `runtime/routepilot.pac`.
4. `Install-EdgeRouting.ps1` embeds the PAC bytes in a user-level Microsoft Edge policy and saves the previous value under ignored local state.
5. `RoutePilotService.cs` is an optional generic process supervisor. The installer configures it to run a Hysteria 2 client as `LocalService`.
6. `Test-RoutePilotHealth.ps1` verifies local ports, service state, Edge policy integrity, certificate lifetime, and an optional expected bulk-route exit.

## Request flow

The PAC makes a decision for each hostname requested by Edge; it does not merge links or inspect account contents.

1. Local and private addresses stay direct.
2. Account, login, payment, and other protected hostnames return only the primary HTTP proxy.
3. Selected media CDN and download hostnames return only the bulk HTTP proxy.
4. The primary proxy may continue through a VPS to a residential upstream. The bulk proxy may use Hysteria 2 over UDP/QUIC to terminate directly on the VPS.

Keeping TCP 443 for the primary tunnel and UDP 443 for the optional bulk tunnel allows both server-side listeners to coexist because TCP and UDP have separate port spaces. The throughput improvement comes primarily from removing the residential upstream from bulk transfers. QUIC-based transport may additionally cope better with latency and loss than a nested TCP forwarding path, but it cannot exceed the actual client/VPS/network capacity.

## Routing invariants

- Local and private-network hosts are direct.
- Protected domains use the primary proxy with no fallback.
- Bulk domains use the bulk proxy with no cross-route fallback.
- Other domains use the primary proxy and may optionally fall back to direct according to local configuration.
- A domain may not appear in both protected and bulk groups.

## Data boundaries

Tracked files contain source, documentation, tests, and placeholders only. Generated PAC files, policy backups, logs, binaries, local configuration, credentials, certificates, and reports are ignored.

See [Performance case study](performance-case-study.md) for measured behavior from the deployment that inspired the project.
