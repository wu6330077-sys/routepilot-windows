[CmdletBinding()]
param(
    [ValidateRange(0, 65535)][int]$PrimaryPort = 0,
    [ValidateRange(0, 65535)][int]$BulkPort = 0,
    [ValidateSet('Prompt', 'Yes', 'No')][string]$DefaultDirectFallback = 'Prompt',
    [ValidateSet('Prompt', 'Yes', 'No')][string]$RequireHysteriaService = 'Prompt',
    [string]$ConfigPath,
    [string]$PacPath,
    [switch]$SkipPortCheck,
    [switch]$SkipEdgeInstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$presetPath = Join-Path $projectRoot 'config\presets\ai-media.json'
if (-not $ConfigPath) { $ConfigPath = Join-Path $projectRoot 'config\routepilot.local.json' }
if (-not $PacPath) { $PacPath = Join-Path $projectRoot 'runtime\routepilot.pac' }

if ($env:OS -ne 'Windows_NT') { throw 'RoutePilot setup currently supports Windows only.' }
if (-not (Test-Path -LiteralPath $presetPath -PathType Leaf)) { throw "Routing preset not found: $presetPath" }

function Read-ProxyPort {
    param([Parameter(Mandatory)][string]$Prompt, [Parameter(Mandatory)][int]$Default, [int]$Provided)
    if ($Provided -gt 0) { return $Provided }
    while ($true) {
        $answer = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        $port = 0
        if ([int]::TryParse($answer, [ref]$port) -and $port -ge 1 -and $port -le 65535) { return $port }
        Write-Host 'Please enter a TCP port from 1 to 65535. / 请输入 1 到 65535 之间的端口。' -ForegroundColor Yellow
    }
}

function Resolve-YesNo {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][bool]$Default
    )
    if ($Value -eq 'Yes') { return $true }
    if ($Value -eq 'No') { return $false }
    while ($true) {
        $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
        $answer = (Read-Host "$Prompt $suffix").Trim().ToLowerInvariant()
        if (-not $answer) { return $Default }
        if ($answer -in @('y', 'yes', '是')) { return $true }
        if ($answer -in @('n', 'no', '否')) { return $false }
        Write-Host 'Please answer Y or N. / 请输入 Y 或 N。' -ForegroundColor Yellow
    }
}

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

Write-Host ''
Write-Host 'RoutePilot beginner setup / RoutePilot 新手配置向导' -ForegroundColor Cyan
Write-Host 'The primary route handles protected traffic; the fast route handles selected large payloads.'
Write-Host '住宅/可信线路负责受保护流量，高速 VPS 线路负责明确列出的大流量。'
Write-Host ''

$PrimaryPort = Read-ProxyPort -Prompt 'Primary residential/trusted HTTP proxy port / 住宅或可信代理端口' -Default 10809 -Provided $PrimaryPort
$BulkPort = Read-ProxyPort -Prompt 'Fast VPS HTTP proxy port / 高速 VPS 代理端口' -Default 10818 -Provided $BulkPort
$fallback = Resolve-YesNo -Value $DefaultDirectFallback -Prompt 'Allow ordinary, non-protected sites to fall back to DIRECT? / 普通非保护网站允许回落直连吗？' -Default $true
$requireService = Resolve-YesNo -Value $RequireHysteriaService -Prompt 'Is the fast proxy managed by the RoutePilot Hysteria service? / 高速代理由 RoutePilot 的 Hysteria 服务托管吗？' -Default $false

if ((Test-Path -LiteralPath $ConfigPath) -and -not $Force) {
    $overwrite = Resolve-YesNo -Value 'Prompt' -Prompt 'A local configuration already exists. Replace it? / 本地配置已经存在，是否替换？' -Default $false
    if (-not $overwrite) {
        Write-Host 'Setup cancelled; the existing configuration was not changed. / 已取消，原配置没有改变。' -ForegroundColor Yellow
        exit 0
    }
    $backupPath = $ConfigPath + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $ConfigPath -Destination $backupPath
    Write-Host "Configuration backup / 配置备份: $backupPath"
}

$config = Get-Content -Raw -LiteralPath $presetPath | ConvertFrom-Json
$config.primaryProxy.port = $PrimaryPort
$config.bulkProxy.port = $BulkPort
$config.defaultDirectFallback = $fallback
$config.health.requireHysteriaService = $requireService

$configDirectory = Split-Path -Parent $ConfigPath
if ($configDirectory) { New-Item -ItemType Directory -Force -Path $configDirectory | Out-Null }
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
& (Join-Path $projectRoot 'scripts\New-RoutePilotPac.ps1') -ConfigPath $ConfigPath -OutputPath $PacPath | Out-Null

if (-not $SkipPortCheck) {
    $primaryReady = Test-LocalPort -Port $PrimaryPort
    $bulkReady = Test-LocalPort -Port $BulkPort
    Write-Host ("Primary proxy / 主代理 {0}: {1}" -f $PrimaryPort, $(if ($primaryReady) { 'READY / 正常' } else { 'NOT READY / 未监听' }))
    Write-Host ("Fast proxy / 高速代理 {0}: {1}" -f $BulkPort, $(if ($bulkReady) { 'READY / 正常' } else { 'NOT READY / 未监听' }))
    if (-not $primaryReady -or -not $bulkReady) {
        Write-Host ''
        Write-Host 'Edge policy was not installed because one or both proxies are unavailable.' -ForegroundColor Yellow
        Write-Host '由于至少一个代理端口不可用，本次没有安装 Edge 分流。请先启动代理，再重新运行向导。' -ForegroundColor Yellow
        Write-Host "Local configuration / 本地配置: $ConfigPath"
        exit 2
    }
}

$edgeInstalled = $false
if (-not $SkipEdgeInstall) {
    $applyEdge = Resolve-YesNo -Value 'Prompt' -Prompt 'Install the reversible Edge routing policy now? / 现在安装可回滚的 Edge 分流策略吗？' -Default $true
    if ($applyEdge) {
        & (Join-Path $projectRoot 'scripts\Install-EdgeRouting.ps1') -ConfigPath $ConfigPath -PacPath $PacPath
        $edgeInstalled = $true
    }
}

Write-Host ''
Write-Host 'Setup completed / 配置完成' -ForegroundColor Green
Write-Host "Primary proxy / 住宅或可信代理: 127.0.0.1:$PrimaryPort"
Write-Host "Fast proxy / 高速 VPS 代理: 127.0.0.1:$BulkPort"
Write-Host "Local configuration / 本地配置: $ConfigPath"
Write-Host "Generated PAC / 生成的 PAC: $PacPath"
if ($edgeInstalled) {
    Write-Host 'Restart Microsoft Edge to activate the new policy. / 请重启 Edge 使策略生效。' -ForegroundColor Cyan
} elseif ($SkipEdgeInstall) {
    Write-Host 'Edge installation was skipped by request. / 已按参数跳过 Edge 安装。'
} else {
    Write-Host 'Edge policy was not installed. Run scripts\Install-EdgeRouting.ps1 later. / Edge 策略未安装，可稍后手动安装。'
}
Write-Host 'Rollback / 回滚: .\scripts\Restore-EdgeRouting.ps1'
