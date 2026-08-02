# Security model

## Goals

- Prevent protected account traffic from leaking to direct access or the bulk route.
- Keep service privileges and credential access narrow.
- Make every operating-system change reversible.
- Prevent deployment-specific data from entering source control.
- Verify third-party downloads before use.

## Trust boundaries

RoutePilot trusts the local Windows administrator, the configured loopback proxy processes, the user's authorized remote endpoints, Microsoft Edge policy enforcement, and the official release metadata used for explicit downloads.

RoutePilot does not protect against a compromised administrator account, malicious proxy software, a hostile remote endpoint, or domain-fronting behavior that is invisible to PAC evaluation.

## Fail-closed behavior

Protected domains return only the primary proxy directive. If the primary proxy is unavailable, the request fails instead of using `DIRECT` or the bulk proxy.

## Least privilege

The optional Hysteria client service runs as `NT AUTHORITY\LocalService`. The installer enables a per-service SID and grants read access only to the selected client configuration and optional certificate paths. Runtime logs receive modify access; no interactive user token is used.

## Supply chain

The download script is never run automatically. It downloads the Hysteria Windows asset and the release `hashes.txt` from the official GitHub release, then requires an exact SHA-256 match before reporting success. Downloaded executables remain ignored by Git.

## Limitations

PAC routing is hostname based. Applications that ignore the Edge policy, use their own network stack, connect by raw IP address, or implement encrypted client-side routing require separate controls.
