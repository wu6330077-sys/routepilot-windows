[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$selfPath = $MyInvocation.MyCommand.Path
$forbiddenExtensions = @('.exe', '.dll', '.pdb', '.key', '.pem', '.pfx', '.crt')
$forbiddenDirectories = @('secrets', 'runtime', 'state', 'reports', 'vendor', 'bin', 'obj')
$textExtensions = @('.ps1', '.cmd', '.bat', '.cs', '.js', '.json', '.yaml', '.yml', '.md', '.txt', '.pac', '.conf')
$findings = @()

$tracked = @()
if (Test-Path -LiteralPath (Join-Path $projectRoot '.git')) {
    $tracked = @(& git -C $projectRoot ls-files --cached --others --exclude-standard)
}
if ($tracked.Count -eq 0) {
    $tracked = @(Get-ChildItem -LiteralPath $projectRoot -Recurse -File | Where-Object {
        $relative = $_.FullName.Substring($projectRoot.Length + 1).Replace('/', '\')
        $relative -notmatch '(^|\\)\.git(\\|$)' -and
            @($relative.Split('\') | Where-Object { $_.ToLowerInvariant() -in $forbiddenDirectories }).Count -eq 0
    } | ForEach-Object { $_.FullName.Substring($projectRoot.Length + 1) })
}

function Test-PublicIPv4 {
    param([Parameter(Mandatory)][string]$Address)
    $parts = @($Address.Split('.') | ForEach-Object { [int]$_ })
    if ($parts[0] -in @(0, 10, 127)) { return $false }
    if ($parts[0] -eq 169 -and $parts[1] -eq 254) { return $false }
    if ($parts[0] -eq 172 -and $parts[1] -ge 16 -and $parts[1] -le 31) { return $false }
    if ($parts[0] -eq 192 -and $parts[1] -eq 168) { return $false }
    if ($parts[0] -eq 192 -and $parts[1] -eq 0 -and $parts[2] -eq 2) { return $false }
    if ($parts[0] -eq 198 -and $parts[1] -eq 51 -and $parts[2] -eq 100) { return $false }
    if ($parts[0] -eq 203 -and $parts[1] -eq 0 -and $parts[2] -eq 113) { return $false }
    if ($parts[0] -ge 224) { return $false }
    return $true
}

foreach ($relativePath in $tracked) {
    if (-not $relativePath) { continue }
    $normalized = $relativePath.Replace('/', '\')
    $segments = $normalized.Split('\')
    $extension = [IO.Path]::GetExtension($normalized).ToLowerInvariant()

    if ($extension -in $forbiddenExtensions) {
        $findings += "${normalized}: forbidden binary or credential-bearing extension"
    }
    if (@($segments | Where-Object { $_.ToLowerInvariant() -in $forbiddenDirectories }).Count -gt 0) {
        $findings += "${normalized}: forbidden generated or private directory"
    }

    $fullPath = Join-Path $projectRoot $normalized
    if ($fullPath -eq $selfPath -or $extension -notin $textExtensions -or -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }
    $content = Get-Content -Raw -LiteralPath $fullPath

    if ($content -match '-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----') {
        $findings += "${normalized}: private key marker"
    }
    if ($content -match '(?i)[A-Z]:\\Users\\[^\\\s]+') {
        $findings += "${normalized}: user-profile absolute path"
    }
    if ($content -match '(?i)(?:vless|hysteria2?|trojan|ss)://[^\s]+') {
        $findings += "${normalized}: proxy or node URI"
    }

    foreach ($match in [regex]::Matches($content, '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])')) {
        if (Test-PublicIPv4 -Address $match.Value) {
            $findings += "${normalized}: public IPv4 address"
            break
        }
    }

    foreach ($line in $content -split "`r?`n") {
        if ($line -match '(?i)^\s*(auth|password|passwd|token|api[_-]?key|secret)\s*[:=]\s*([^\s#]+)') {
            $value = $Matches[2]
            if ($value -notmatch '(?i)^(REPLACE|EXAMPLE|CHANGEME|YOUR_|\$\{|<)') {
                $findings += "${normalized}: possible credential assignment"
                break
            }
        }
    }
}

$findings = @($findings | Sort-Object -Unique)
if ($findings.Count -gt 0) {
    $findings | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output ("secret_scan_files={0}" -f $tracked.Count)
Write-Output 'secret_scan=ok'
