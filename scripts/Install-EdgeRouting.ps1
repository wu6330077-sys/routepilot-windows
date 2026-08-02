[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$ConfigPath,
    [string]$PacPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigPath) { $ConfigPath = Join-Path $projectRoot 'config\routepilot.local.json' }
if (-not $PacPath) { $PacPath = Join-Path $projectRoot 'runtime\routepilot.pac' }

$stateDirectory = Join-Path $projectRoot 'state'
$backupPath = Join-Path $stateDirectory 'edge-proxy-policy-backup.json'
$registryPath = 'HKCU:\Software\Policies\Microsoft\Edge'

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Create local configuration first: $ConfigPath"
}

& (Join-Path $PSScriptRoot 'New-RoutePilotPac.ps1') -ConfigPath $ConfigPath -OutputPath $PacPath | Out-Null
$pacBytes = [IO.File]::ReadAllBytes($PacPath)
$pacUrl = 'data:application/x-ns-proxy-autoconfig;base64,' + [Convert]::ToBase64String($pacBytes)
$policy = [ordered]@{
    ProxyMode = 'pac_script'
    ProxyPacMandatory = $true
    ProxyPacUrl = $pacUrl
} | ConvertTo-Json -Compress

if ($policy.Length -gt 30000) { throw 'Encoded Edge proxy policy is unexpectedly large.' }

$keyExisted = Test-Path -LiteralPath $registryPath
$oldValueExisted = $false
$oldValue = $null
if ($keyExisted) {
    $oldProperties = Get-ItemProperty -LiteralPath $registryPath
    $oldValueExisted = $oldProperties.PSObject.Properties.Name -contains 'ProxySettings'
    if ($oldValueExisted) { $oldValue = [string]$oldProperties.ProxySettings }
}

if (-not (Test-Path -LiteralPath $backupPath)) {
    New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
    [pscustomobject]@{
        CreatedAt = (Get-Date).ToString('o')
        RegistryPath = $registryPath
        KeyExisted = $keyExisted
        ProxySettingsExisted = $oldValueExisted
        ProxySettings = $oldValue
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $backupPath -Encoding UTF8
}

if (-not $PSCmdlet.ShouldProcess($registryPath, 'Install embedded RoutePilot PAC policy')) {
    Write-Output 'edge_policy=unchanged'
    exit 0
}

New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty -Path $registryPath -Name 'ProxySettings' -PropertyType String -Value $policy -Force | Out-Null

$readBack = [string](Get-ItemPropertyValue -Path $registryPath -Name 'ProxySettings')
if ($readBack -ne $policy) { throw 'Edge policy read-back verification failed.' }

Write-Output 'edge_policy=applied'
Write-Output 'restart_edge_required=1'
Write-Output "backup=$backupPath"
