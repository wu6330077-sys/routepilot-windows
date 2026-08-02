[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('routepilot-setup-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

try {
    $configPath = Join-Path $testRoot 'routepilot.local.json'
    $pacPath = Join-Path $testRoot 'routepilot.pac'
    & (Join-Path $projectRoot 'Setup-RoutePilot.ps1') `
        -PrimaryPort 18080 `
        -BulkPort 18081 `
        -DefaultDirectFallback No `
        -RequireHysteriaService No `
        -ConfigPath $configPath `
        -PacPath $pacPath `
        -SkipPortCheck `
        -SkipEdgeInstall `
        -Force | Out-Null

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Setup wizard did not create local configuration.' }
    if (-not (Test-Path -LiteralPath $pacPath -PathType Leaf)) { throw 'Setup wizard did not generate a PAC file.' }

    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    if ([int]$config.primaryProxy.port -ne 18080) { throw 'Primary port was not saved.' }
    if ([int]$config.bulkProxy.port -ne 18081) { throw 'Bulk port was not saved.' }
    if ([bool]$config.defaultDirectFallback) { throw 'Default fallback choice was not saved.' }
    if (@($config.protectedDomains).Count -lt 10) { throw 'The practical preset has too few protected domains.' }
    if (@($config.bulkDomains).Count -lt 10) { throw 'The practical preset has too few bulk domains.' }

    & node (Join-Path $projectRoot 'tests\Test-RoutingPac.js') $pacPath $configPath
    if ($LASTEXITCODE -ne 0) { throw 'Generated beginner PAC failed routing tests.' }

    Write-Output 'setup_wizard_tests=1'
    Write-Output 'status=ok'
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
