[CmdletBinding()]
param(
    [string]$Version = 'latest',
    [string]$Destination
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Destination) { $Destination = Join-Path $projectRoot 'runtime\hysteria' }

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$apiUri = if ($Version -eq 'latest') {
    'https://api.github.com/repos/apernet/hysteria/releases/latest'
} else {
    'https://api.github.com/repos/apernet/hysteria/releases/tags/' + [Uri]::EscapeDataString($Version)
}
$release = Invoke-RestMethod -Uri $apiUri -Headers @{
    'User-Agent' = 'RoutePilot-Hysteria-Downloader'
    'Accept' = 'application/vnd.github+json'
}

$wanted = @('hashes.txt', 'hysteria-windows-amd64.exe')
foreach ($name in $wanted) {
    $asset = @($release.assets | Where-Object name -eq $name)
    if ($asset.Count -ne 1) {
        throw "Official release asset not found or ambiguous: $name"
    }
    Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile (Join-Path $Destination $name)
}

$expected = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $Destination 'hashes.txt')) {
    if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
        $assetName = Split-Path -Leaf $Matches[2].Trim()
        $expected[$assetName] = $Matches[1].ToLowerInvariant()
    }
}

$binaryName = 'hysteria-windows-amd64.exe'
if (-not $expected.ContainsKey($binaryName)) {
    throw "No SHA-256 entry found for $binaryName."
}
$binaryPath = Join-Path $Destination $binaryName
$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $binaryPath).Hash.ToLowerInvariant()
if ($actual -ne $expected[$binaryName]) {
    Remove-Item -LiteralPath $binaryPath -Force -ErrorAction SilentlyContinue
    throw "SHA-256 mismatch for $binaryName. The unverified binary was removed."
}

[pscustomobject]@{
    Tag = $release.tag_name
    PublishedAt = $release.published_at
    Binary = [IO.Path]::GetFullPath($binaryPath)
    Sha256Verified = $true
} | ConvertTo-Json -Depth 3
