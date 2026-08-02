# Beginner guide

This guide assumes you have never edited a PAC file or installed a Windows service.

## Before you begin

RoutePilot routes traffic; it does not create the two network routes. Start these first:

1. A local HTTP proxy that exits through your residential or trusted connection.
2. A local HTTP proxy that exits directly through your high-bandwidth VPS.

If you use different software or ports, that is fine. The setup wizard asks for the two port numbers.

## Step 1: get the project

Either clone the repository with Git or use **Code → Download ZIP** on GitHub and extract it. Open the extracted RoutePilot folder. If Windows marks downloaded scripts as blocked, click the File Explorer address bar, type `powershell`, press Enter, and run:

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

## Step 2: double-click the wizard

Double-click `Start-Setup.cmd` in the project root. It starts PowerShell in the correct folder and keeps the result visible.

If Windows or security software blocks the launcher, open PowerShell in the project folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-RoutePilot.ps1
```

The defaults are:

- primary residential/trusted HTTP proxy: `127.0.0.1:10809`;
- fast VPS HTTP proxy: `127.0.0.1:10818`.

Press Enter to accept a default or type your actual port. The wizard creates `config/routepilot.local.json`, which is ignored by Git.

## Step 3: read the port check

Both ports must show `READY`. If either shows `NOT READY`, RoutePilot deliberately does not modify Edge. Start or repair that proxy and run the wizard again.

RoutePilot expects an **HTTP proxy** at both ports. A SOCKS-only port cannot be used by the generated `PROXY` PAC directive.

## Step 4: install and activate Edge routing

When both ports are ready, answer `Y` when the wizard asks to install the Edge policy. Close every Edge window and start Edge again.

Edge may display “Managed by your organization.” This is expected because RoutePilot uses the current user's local Edge policy. It does not join the computer to an external organization.

## What is changed?

- A generated PAC file is written under ignored local runtime data.
- The previous Edge `ProxySettings` value is backed up under ignored local state.
- A new embedded PAC policy is installed for the current Windows user.

The wizard does not change the active node in your proxy application, enable TUN, restart your proxy, or upload configuration.

## Rollback

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-EdgeRouting.ps1
```

Restart Edge afterward.

## Common problems

### A port is not ready

Check it directly:

```powershell
Test-NetConnection 127.0.0.1 -Port 10809
Test-NetConnection 127.0.0.1 -Port 10818
```

Look for `TcpTestSucceeded : True`.

### I only have one proxy

RoutePilot cannot create a second remote route by itself. Prepare an authorized VPS proxy first. If you already operate a Hysteria 2 server, follow the [manual installation guide](manual-install.md) to host its Windows client as a service.

### I chose the wrong ports

Run the wizard again. It offers to back up the current local configuration before replacing it.

### Edge stopped loading protected sites

This normally means the primary proxy is unavailable. Protected domains intentionally fail closed. Start the primary proxy or restore the previous Edge policy.
