# Security policy

## Reporting a vulnerability

Please do not disclose exploitable vulnerabilities in a public issue. Use GitHub private vulnerability reporting when it is enabled for the repository. If private reporting is unavailable, open a minimal issue asking the maintainer for a private contact channel without including exploit details.

## Supported versions

Only the latest tagged release is supported during the initial development phase.

## Secrets and logs

RoutePilot does not require secrets in tracked files. Hysteria authentication, private CA files, expected exit addresses, and local paths belong only in ignored local configuration. Runtime logs may contain endpoint metadata and should be treated as private.

RoutePilot has no telemetry and does not upload configuration or health results.
