[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$PacPath,
    [switch]$Online
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigPath) { $ConfigPath = Join-Path $projectRoot 'config\routepilot.local.json' }
if (-not $PacPath) { $PacPath = Join-Path $projectRoot 'runtime\routepilot.pac' }
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw "Configuration not found: $ConfigPath" }
if (-not (Test-Path -LiteralPath $PacPath -PathType Leaf)) { throw "Generated PAC not found: $PacPath" }

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$registryPath = 'HKCU:\Software\Policies\Microsoft\Edge'
$serviceName = 'RoutePilotHysteriaClient'

function Test-LocalPort {
    param([Parameter(Mandatory)][int]$Port)
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $pending = $tcp.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(500)) { return $false }
        $tcp.EndConnect($pending)
        return $true
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

$primaryPort = [int]$config.primaryProxy.port
$bulkPort = [int]$config.bulkProxy.port
$primaryReady = Test-LocalPort -Port $primaryPort
$bulkReady = Test-LocalPort -Port $bulkPort
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
$serviceReady = $service -and $service.Status -eq 'Running'

$policyOk = $false
$pacHashOk = $false
try {
    $rawPolicy = [string](Get-ItemPropertyValue -Path $registryPath -Name 'ProxySettings')
    $policy = $rawPolicy | ConvertFrom-Json
    $policyOk = $policy.ProxyMode -eq 'pac_script' -and $policy.ProxyPacMandatory -eq $true
    $prefix = 'data:application/x-ns-proxy-autoconfig;base64,'
    if ([string]$policy.ProxyPacUrl -and ([string]$policy.ProxyPacUrl).StartsWith($prefix)) {
        $embedded = [Convert]::FromBase64String(([string]$policy.ProxyPacUrl).Substring($prefix.Length))
        $local = [IO.File]::ReadAllBytes($PacPath)
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $embeddedHash = [BitConverter]::ToString($sha.ComputeHash($embedded))
            $localHash = [BitConverter]::ToString($sha.ComputeHash($local))
            $pacHashOk = $embeddedHash -eq $localHash
        } finally {
            $sha.Dispose()
        }
    }
} catch { }

$certificateDaysRemaining = $null
$certificateOk = $null
$certificatePath = [string]$config.health.certificatePath
if (-not [string]::IsNullOrWhiteSpace($certificatePath)) {
    if (Test-Path -LiteralPath $certificatePath -PathType Leaf) {
        $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
        $certificateDaysRemaining = [math]::Floor(($certificate.NotAfter.ToUniversalTime() - [DateTime]::UtcNow).TotalDays)
        $certificateOk = $certificateDaysRemaining -gt 30
    } else {
        $certificateOk = $false
    }
}

$onlineOk = $null
$expectedBulkExit = ([string]$config.health.expectedBulkExit).Trim()
if ($Online -and $expectedBulkExit) {
    $onlineOk = $false
    $checkUrl = ([string]$config.health.checkUrl).Trim()
    if (-not $checkUrl) { $checkUrl = 'https://api.ipify.org' }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $proxyUrl = "http://127.0.0.1:$bulkPort"
            $actualExit = (& curl.exe -4 -sS --max-time 20 -x $proxyUrl $checkUrl | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $actualExit -eq $expectedBulkExit) {
                $onlineOk = $true
                break
            }
        } catch { }
        if ($attempt -lt 3) { Start-Sleep -Seconds 1 }
    }
}

$requiredPrimary = -not [bool]$config.health.requirePrimaryProxy -or $primaryReady
$requiredService = -not [bool]$config.health.requireHysteriaService -or $serviceReady
$healthy = $requiredPrimary -and $requiredService -and $bulkReady -and $policyOk -and $pacHashOk -and ($certificateOk -ne $false) -and ($onlineOk -ne $false)

$result = [pscustomobject]@{
    CheckedAt = (Get-Date).ToString('o')
    Healthy = $healthy
    PrimaryProxyPort = $primaryPort
    PrimaryProxyReady = $primaryReady
    BulkProxyPort = $bulkPort
    BulkProxyReady = $bulkReady
    HysteriaService = if ($service) { [string]$service.Status } else { 'Missing' }
    EdgePolicyValid = $policyOk
    EmbeddedPacMatchesFile = $pacHashOk
    CertificateDaysRemaining = $certificateDaysRemaining
    CertificateMoreThan30Days = $certificateOk
    OnlineBulkExitMatchesExpected = $onlineOk
}
$result | ConvertTo-Json -Depth 3
if (-not $healthy) { exit 2 }
