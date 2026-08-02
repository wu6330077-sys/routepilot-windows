[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $projectRoot 'scripts\New-RoutePilotPac.ps1'
$example = Join-Path $projectRoot 'config\routepilot.example.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('routepilot-config-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

function Assert-Rejected {
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Name)
    $configPath = Join-Path $testRoot "$Name.json"
    $outputPath = Join-Path $testRoot "$Name.pac"
    $Config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
    $rejected = $false
    try {
        & $generator -ConfigPath $configPath -OutputPath $outputPath | Out-Null
    } catch {
        $rejected = $true
    }
    if (-not $rejected) { throw "Invalid configuration was accepted: $Name" }
}

try {
    $validOutput = Join-Path $testRoot 'valid.pac'
    & $generator -ConfigPath $example -OutputPath $validOutput | Out-Null
    if (-not (Test-Path -LiteralPath $validOutput -PathType Leaf)) { throw 'Valid configuration did not produce a PAC file.' }

    $remoteProxy = Get-Content -Raw -LiteralPath $example | ConvertFrom-Json
    $remoteProxy.primaryProxy.host = 'proxy.example.com'
    Assert-Rejected -Config $remoteProxy -Name 'remote-proxy'

    $overlap = Get-Content -Raw -LiteralPath $example | ConvertFrom-Json
    $overlap.bulkDomains = @($overlap.bulkDomains) + @($overlap.protectedDomains[0])
    Assert-Rejected -Config $overlap -Name 'overlapping-domains'

    $nestedOverlap = Get-Content -Raw -LiteralPath $example | ConvertFrom-Json
    $nestedOverlap.protectedDomains = @('example.com')
    $nestedOverlap.bulkDomains = @('download.example.com')
    Assert-Rejected -Config $nestedOverlap -Name 'nested-overlapping-domains'

    $invalidDomain = Get-Content -Raw -LiteralPath $example | ConvertFrom-Json
    $invalidDomain.protectedDomains = @('not a domain')
    Assert-Rejected -Config $invalidDomain -Name 'invalid-domain'

    Write-Output 'config_validation_tests=5'
    Write-Output 'status=ok'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
