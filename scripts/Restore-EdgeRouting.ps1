[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backupPath = Join-Path $projectRoot 'state\edge-proxy-policy-backup.json'
$registryPath = 'HKCU:\Software\Policies\Microsoft\Edge'

if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    throw "Policy backup is missing: $backupPath"
}
$backup = Get-Content -Raw -LiteralPath $backupPath | ConvertFrom-Json

if (-not $PSCmdlet.ShouldProcess($registryPath, 'Restore previous Edge proxy policy')) {
    Write-Output 'edge_policy=unchanged'
    exit 0
}

if ([bool]$backup.ProxySettingsExisted) {
    New-Item -Path $registryPath -Force | Out-Null
    New-ItemProperty -Path $registryPath -Name 'ProxySettings' -PropertyType String -Value ([string]$backup.ProxySettings) -Force | Out-Null
} elseif (Test-Path -LiteralPath $registryPath) {
    Remove-ItemProperty -Path $registryPath -Name 'ProxySettings' -ErrorAction SilentlyContinue
}

Write-Output 'edge_policy=restored'
Write-Output 'restart_edge_required=1'
