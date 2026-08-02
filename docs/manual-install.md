# Manual installation

Use this path when you want full control over configuration or need RoutePilot to supervise a Hysteria 2 client.

## 1. Create local configuration

```powershell
Copy-Item .\config\routepilot.example.json .\config\routepilot.local.json
Copy-Item .\config\hysteria-client.example.yaml .\config\hysteria-client.local.yaml
```

Edit the local files. Replace placeholders only in `*.local.*` files; they are ignored by Git.

To start from the practical AI-and-media preset instead of the minimal example:

```powershell
Copy-Item .\config\presets\ai-media.json .\config\routepilot.local.json
```

## 2. Generate and test the PAC

```powershell
.\scripts\New-RoutePilotPac.ps1
node .\tests\Test-RoutingPac.js .\runtime\routepilot.pac .\config\routepilot.local.json
```

Node.js is used only for the developer/offline PAC test, not for normal Edge routing.

## 3. Optional: install a Hysteria 2 client service

RoutePilot does not configure the remote Hysteria 2 server. Use only a server you own or are authorized to administer.

Explicitly download the official Windows binary and verify its published SHA-256:

```powershell
.\scripts\Download-Hysteria.ps1
```

From an elevated PowerShell terminal:

```powershell
.\scripts\Install-HysteriaService.ps1 `
  -HysteriaExecutable .\runtime\hysteria\hysteria-windows-amd64.exe `
  -ClientConfig .\config\hysteria-client.local.yaml `
  -DataRoot D:\RoutePilotData
```

If the YAML references a private CA file, pass that file with `-AdditionalReadPath`. The service runs as `LocalService` and needs explicit read access.

## 4. Install Edge routing

```powershell
.\scripts\Install-EdgeRouting.ps1
```

Restart all Edge windows.

## 5. Health check

```powershell
.\scripts\Test-RoutePilotHealth.ps1
```

To verify a configured expected bulk exit, set it only in the ignored local JSON and add `-Online`.

## Rollback

```powershell
.\scripts\Restore-EdgeRouting.ps1
.\scripts\Uninstall-HysteriaService.ps1
```

The service uninstaller retains diagnostic data unless `-RemoveData` is explicitly supplied.
