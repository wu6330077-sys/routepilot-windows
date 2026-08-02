[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$snapshotScript = Join-Path $projectRoot 'scripts\Get-RoutePilotSnapshot.ps1'
$generator = Join-Path $projectRoot 'scripts\New-RoutePilotPac.ps1'
$configPath = Join-Path $projectRoot 'config\presets\ai-media.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('routepilot-monitor-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

try {
    $pacPath = Join-Path $testRoot 'routepilot.pac'
    & $generator -ConfigPath $configPath -OutputPath $pacPath | Out-Null
    $pacBytes = [IO.File]::ReadAllBytes($pacPath)
    $policyPath = Join-Path $testRoot 'policy.json'
    [ordered]@{
        ProxyMode = 'pac_script'
        ProxyPacMandatory = $true
        ProxyPacUrl = 'data:application/x-ns-proxy-autoconfig;base64,' + [Convert]::ToBase64String($pacBytes)
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $policyPath -Encoding UTF8

    $active = & $snapshotScript -ConfigPath $configPath -PolicyJsonPath $policyPath -SkipBenchmark
    if (-not $active.RoutePilotPolicyActive -or $active.PolicyState -ne 'Active') {
        throw 'The monitor did not recognize an active RoutePilot policy.'
    }
    if ($active.Primary.Port -ne 10809 -or $active.Bulk.Port -ne 10818) {
        throw 'The monitor did not read proxy ports from configuration.'
    }
    if ($null -ne $active.Primary.MedianMbps -or $null -ne $active.Bulk.MedianMbps) {
        throw 'SkipBenchmark unexpectedly produced speed measurements.'
    }

    $otherPolicyPath = Join-Path $testRoot 'other-policy.json'
    '{"ProxyMode":"direct"}' | Set-Content -LiteralPath $otherPolicyPath -Encoding UTF8
    $inactive = & $snapshotScript -ConfigPath $configPath -PolicyJsonPath $otherPolicyPath -SkipBenchmark
    if ($inactive.RoutePilotPolicyActive -or $inactive.PolicyState -ne 'OtherPolicy') {
        throw 'The monitor incorrectly identified an unrelated policy as RoutePilot.'
    }

    $json = & $snapshotScript -ConfigPath $configPath -PolicyJsonPath $policyPath -SkipBenchmark -AsJson | ConvertFrom-Json
    if ($json.SchemaVersion -ne 1 -or -not $json.RoutePilotPolicyActive) {
        throw 'The JSON snapshot output is invalid.'
    }

    Write-Output 'monitor_snapshot_tests=3'
    Write-Output 'status=ok'
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
