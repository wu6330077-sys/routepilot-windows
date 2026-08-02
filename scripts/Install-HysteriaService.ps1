[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$HysteriaExecutable,
    [Parameter(Mandatory)][string]$ClientConfig,
    [string[]]$AdditionalReadPath = @(),
    [string]$DataRoot = (Join-Path $env:ProgramData 'RoutePilot'),
    [ValidateRange(1, 65535)][int]$ListenPort = 10818,
    [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$serviceName = 'RoutePilotHysteriaClient'
$projectRoot = Split-Path -Parent $PSScriptRoot

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell terminal.'
}

function Resolve-RequiredFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label not found: $Path" }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Test-LocalPort {
    param([Parameter(Mandatory)][int]$Port)
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(300)) { return $false }
        $tcp.EndConnect($pending)
        return $true
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

$sourceHysteria = Resolve-RequiredFile -Path $HysteriaExecutable -Label 'Hysteria executable'
$sourceConfig = Resolve-RequiredFile -Path $ClientConfig -Label 'Hysteria client configuration'
$resolvedAdditional = @()
foreach ($path in $AdditionalReadPath) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Additional read path not found: $path" }
    $resolvedAdditional += (Resolve-Path -LiteralPath $path).Path
}

$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing -and -not $Replace) {
    throw "Service $serviceName already exists. Use -Replace to replace it explicitly."
}
if (-not $existing -and (Test-LocalPort -Port $ListenPort)) {
    throw "Port $ListenPort is already in use. Stop the conflicting process before installation."
}

$serviceDirectory = Join-Path $DataRoot 'service'
$binaryDirectory = Join-Path $DataRoot 'bin'
$logDirectory = Join-Path $DataRoot 'logs'
$installedService = Join-Path $serviceDirectory 'RoutePilotService.exe'
$installedHysteria = Join-Path $binaryDirectory 'hysteria.exe'
$serviceConfig = Join-Path $serviceDirectory 'service.conf'
$serviceLog = Join-Path $logDirectory 'hysteria-client.log'
$buildOutput = Join-Path $projectRoot 'runtime\build\RoutePilotService.exe'

if (-not $PSCmdlet.ShouldProcess($serviceName, 'Install a LocalService Hysteria client supervisor')) {
    Write-Output 'service=unchanged'
    exit 0
}

if ($existing) {
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to delete existing service: $LASTEXITCODE" }
    Start-Sleep -Seconds 1
}

New-Item -ItemType Directory -Force -Path $serviceDirectory, $binaryDirectory, $logDirectory | Out-Null
& (Join-Path $PSScriptRoot 'Build-Service.ps1') -OutputPath $buildOutput | Out-Null
Copy-Item -LiteralPath $buildOutput -Destination $installedService -Force
Copy-Item -LiteralPath $sourceHysteria -Destination $installedHysteria -Force

@(
    "Executable=$installedHysteria"
    "Arguments=client --config `"$sourceConfig`""
    "WorkingDirectory=$binaryDirectory"
    "LogPath=$serviceLog"
    'RestartDelayMilliseconds=3000'
) | Set-Content -LiteralPath $serviceConfig -Encoding UTF8

$binPath = '"' + $installedService + '"'
& sc.exe create $serviceName binPath= $binPath start= delayed-auto obj= 'NT AUTHORITY\LocalService' DisplayName= 'RoutePilot Hysteria Client' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "sc.exe create failed: $LASTEXITCODE" }
& sc.exe description $serviceName 'Least-privilege Hysteria 2 client supervised by RoutePilot.' | Out-Null
& sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
& sc.exe failureflag $serviceName 1 | Out-Null
& sc.exe sidtype $serviceName unrestricted | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to enable the per-service SID.' }

$serviceIdentity = "NT SERVICE\$serviceName"
& icacls.exe $DataRoot /grant:r "${serviceIdentity}:(OI)(CI)(RX)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to grant service data read access.' }
& icacls.exe $logDirectory /grant:r "${serviceIdentity}:(OI)(CI)(M)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to grant service log access.' }
& icacls.exe $sourceConfig /grant:r "${serviceIdentity}:(R)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to grant client configuration read access.' }

foreach ($path in $resolvedAdditional) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        & icacls.exe $path /grant:r "${serviceIdentity}:(OI)(CI)(RX)" | Out-Null
    } else {
        & icacls.exe $path /grant:r "${serviceIdentity}:(R)" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Failed to grant service read access: $path" }
}

Start-Service -Name $serviceName
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 500
    if (Test-LocalPort -Port $ListenPort) {
        $ready = $true
        break
    }
}

$service = Get-CimInstance Win32_Service -Filter "Name='$serviceName'"
$verified = $ready -and $service.State -eq 'Running' -and $service.StartMode -eq 'Auto'
$result = [pscustomobject]@{
    ServiceName = $serviceName
    State = $service.State
    StartMode = $service.StartMode
    DelayedAutoStart = [bool]$service.DelayedAutoStart
    Account = $service.StartName
    ListenPort = $ListenPort
    PortReady = $ready
    DataRoot = [IO.Path]::GetFullPath($DataRoot)
    Verified = $verified
}
$result | ConvertTo-Json -Depth 3
if (-not $verified) { exit 2 }
