# RoutePilot contributor rules

- Keep the project portable: derive paths from `$PSScriptRoot` or explicit parameters.
- Never add real proxy credentials, node URIs, public server IPs, certificates, local logs, or user-specific absolute paths.
- Local settings belong in `config/*.local.*`; those files are ignored by Git.
- Do not commit compiled binaries or vendored dependencies.
- Hysteria downloads must come from the official GitHub release and pass the published SHA-256 check.
- Protected-domain traffic must fail closed; do not add a `DIRECT` or bulk-proxy fallback to that route.
- Any change to routing must pass `tests/Test-RoutingPac.js` and `tests/Test-NoSecrets.ps1`.
- Installation scripts must provide a reversible uninstall or restore path.
