# Contributing

Issues and pull requests are welcome.

## Development workflow

1. Fork the repository and create a focused branch.
2. Do not include real endpoints, credentials, certificates, node links, logs, or user-specific paths in examples or tests.
3. Keep protected-domain routing fail closed.
4. Run all tests before opening a pull request:

```powershell
.\tests\Test-PowerShellSyntax.ps1
.\tests\Test-ConfigValidation.ps1
.\scripts\New-RoutePilotPac.ps1 -ConfigPath .\config\routepilot.example.json
node .\tests\Test-RoutingPac.js .\runtime\routepilot.pac .\config\routepilot.example.json
.\scripts\Build-Service.ps1
.\tests\Test-NoSecrets.ps1
```

5. Explain user-visible changes in `CHANGELOG.md`.

Changes that weaken credential isolation, add automatic third-party binary updates, or introduce silent direct fallbacks for protected domains will not be accepted.
