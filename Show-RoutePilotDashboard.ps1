[CmdletBinding()]
param([string]$ConfigPath)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'The RoutePilot dashboard currently supports Windows only.' }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$projectRoot = $PSScriptRoot
$snapshotScript = Join-Path $projectRoot 'scripts\Get-RoutePilotSnapshot.ps1'
$setupScript = Join-Path $projectRoot 'Setup-RoutePilot.ps1'
if (-not $ConfigPath) {
    $localConfig = Join-Path $projectRoot 'config\routepilot.local.json'
    $ConfigPath = if (Test-Path -LiteralPath $localConfig -PathType Leaf) {
        $localConfig
    } else {
        Join-Path $projectRoot 'config\presets\ai-media.json'
    }
}

$colors = @{
    Background = [Drawing.Color]::FromArgb(245, 247, 250)
    Card = [Drawing.Color]::White
    Text = [Drawing.Color]::FromArgb(31, 41, 55)
    Muted = [Drawing.Color]::FromArgb(107, 114, 128)
    Green = [Drawing.Color]::FromArgb(22, 163, 74)
    Red = [Drawing.Color]::FromArgb(220, 38, 38)
    Blue = [Drawing.Color]::FromArgb(37, 99, 235)
    Orange = [Drawing.Color]::FromArgb(234, 88, 12)
}
$fontName = 'Microsoft YaHei UI'

function New-TextLabel {
    param([string]$Text, [float]$Size = 10, [Drawing.FontStyle]$Style = [Drawing.FontStyle]::Regular)
    $label = New-Object Windows.Forms.Label
    $label.Text = $Text
    $label.Font = New-Object Drawing.Font($fontName, $Size, $Style)
    $label.ForeColor = $colors.Text
    $label.AutoSize = $true
    return $label
}

$form = New-Object Windows.Forms.Form
$form.Text = 'RoutePilot 线路测试仪表盘'
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
$form.ClientSize = New-Object Drawing.Size(920, 650)
$form.MinimumSize = New-Object Drawing.Size(820, 620)
$form.BackColor = $colors.Background
$form.Font = New-Object Drawing.Font($fontName, 10)

$title = New-TextLabel -Text 'RoutePilot 线路测试' -Size 22 -Style Bold
$title.Location = New-Object Drawing.Point(34, 24)
$form.Controls.Add($title)

$subtitle = New-TextLabel -Text '客观显示两条本地代理线路的连接状态与测速结果' -Size 10
$subtitle.ForeColor = $colors.Muted
$subtitle.Location = New-Object Drawing.Point(37, 65)
$form.Controls.Add($subtitle)

$statusPanel = New-Object Windows.Forms.Panel
$statusPanel.Location = New-Object Drawing.Point(620, 22)
$statusPanel.Size = New-Object Drawing.Size(260, 68)
$statusPanel.BackColor = $colors.Card
$statusPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($statusPanel)

$statusTitle = New-TextLabel -Text '正在检查…' -Size 14 -Style Bold
$statusTitle.Location = New-Object Drawing.Point(18, 10)
$statusPanel.Controls.Add($statusTitle)
$statusDetail = New-TextLabel -Text '' -Size 8.5
$statusDetail.ForeColor = $colors.Muted
$statusDetail.Location = New-Object Drawing.Point(19, 39)
$statusPanel.Controls.Add($statusDetail)

$primaryBox = New-Object Windows.Forms.GroupBox
$primaryBox.Text = '① 主线路：住宅 / 可信出口'
$primaryBox.Font = New-Object Drawing.Font($fontName, 11, [Drawing.FontStyle]::Bold)
$primaryBox.Location = New-Object Drawing.Point(35, 115)
$primaryBox.Size = New-Object Drawing.Size(410, 175)
$primaryBox.BackColor = $colors.Card
$form.Controls.Add($primaryBox)

$primaryEndpoint = New-TextLabel -Text '端口：检查中' -Size 10
$primaryEndpoint.Location = New-Object Drawing.Point(20, 35)
$primaryBox.Controls.Add($primaryEndpoint)
$primaryReady = New-TextLabel -Text '状态：检查中' -Size 10
$primaryReady.Location = New-Object Drawing.Point(20, 68)
$primaryBox.Controls.Add($primaryReady)
$primarySpeed = New-TextLabel -Text '尚未测速' -Size 18 -Style Bold
$primarySpeed.ForeColor = $colors.Blue
$primarySpeed.Location = New-Object Drawing.Point(20, 104)
$primaryBox.Controls.Add($primarySpeed)
$primaryUnit = New-TextLabel -Text '单连接中位速度' -Size 8.5
$primaryUnit.ForeColor = $colors.Muted
$primaryUnit.Location = New-Object Drawing.Point(22, 140)
$primaryBox.Controls.Add($primaryUnit)

$bulkBox = New-Object Windows.Forms.GroupBox
$bulkBox.Text = '② 高速线路：VPS 大流量出口'
$bulkBox.Font = New-Object Drawing.Font($fontName, 11, [Drawing.FontStyle]::Bold)
$bulkBox.Location = New-Object Drawing.Point(475, 115)
$bulkBox.Size = New-Object Drawing.Size(410, 175)
$bulkBox.BackColor = $colors.Card
$form.Controls.Add($bulkBox)

$bulkEndpoint = New-TextLabel -Text '端口：检查中' -Size 10
$bulkEndpoint.Location = New-Object Drawing.Point(20, 35)
$bulkBox.Controls.Add($bulkEndpoint)
$bulkReady = New-TextLabel -Text '状态：检查中' -Size 10
$bulkReady.Location = New-Object Drawing.Point(20, 68)
$bulkBox.Controls.Add($bulkReady)
$bulkSpeed = New-TextLabel -Text '尚未测速' -Size 18 -Style Bold
$bulkSpeed.ForeColor = $colors.Orange
$bulkSpeed.Location = New-Object Drawing.Point(20, 104)
$bulkBox.Controls.Add($bulkSpeed)
$bulkUnit = New-TextLabel -Text '单连接中位速度' -Size 8.5
$bulkUnit.ForeColor = $colors.Muted
$bulkUnit.Location = New-Object Drawing.Point(22, 140)
$bulkBox.Controls.Add($bulkUnit)

$comparisonBox = New-Object Windows.Forms.GroupBox
$comparisonBox.Text = '两条线路测速对比'
$comparisonBox.Font = New-Object Drawing.Font($fontName, 11, [Drawing.FontStyle]::Bold)
$comparisonBox.Location = New-Object Drawing.Point(35, 310)
$comparisonBox.Size = New-Object Drawing.Size(850, 195)
$comparisonBox.BackColor = $colors.Card
$form.Controls.Add($comparisonBox)

$beforeLabel = New-TextLabel -Text '主线路测速结果' -Size 10
$beforeLabel.Location = New-Object Drawing.Point(22, 38)
$comparisonBox.Controls.Add($beforeLabel)
$primaryBar = New-Object Windows.Forms.ProgressBar
$primaryBar.Location = New-Object Drawing.Point(25, 69)
$primaryBar.Size = New-Object Drawing.Size(795, 22)
$primaryBar.Style = 'Continuous'
$comparisonBox.Controls.Add($primaryBar)

$afterLabel = New-TextLabel -Text '高速线路测速结果' -Size 10
$afterLabel.Location = New-Object Drawing.Point(22, 105)
$comparisonBox.Controls.Add($afterLabel)
$bulkBar = New-Object Windows.Forms.ProgressBar
$bulkBar.Location = New-Object Drawing.Point(25, 136)
$bulkBar.Size = New-Object Drawing.Size(795, 22)
$bulkBar.Style = 'Continuous'
$comparisonBox.Controls.Add($bulkBar)

$gainLabel = New-TextLabel -Text '点击“开始对比测速”查看两条候选线路的差异' -Size 10 -Style Bold
$gainLabel.ForeColor = $colors.Blue
$gainLabel.Location = New-Object Drawing.Point(25, 164)
$comparisonBox.Controls.Add($gainLabel)

$benchmarkButton = New-Object Windows.Forms.Button
$benchmarkButton.Text = '开始对比测速'
$benchmarkButton.Location = New-Object Drawing.Point(35, 530)
$benchmarkButton.Size = New-Object Drawing.Size(180, 46)
$benchmarkButton.BackColor = $colors.Blue
$benchmarkButton.ForeColor = [Drawing.Color]::White
$benchmarkButton.FlatStyle = 'Flat'
$benchmarkButton.Font = New-Object Drawing.Font($fontName, 11, [Drawing.FontStyle]::Bold)
$form.Controls.Add($benchmarkButton)

$refreshButton = New-Object Windows.Forms.Button
$refreshButton.Text = '刷新启用状态'
$refreshButton.Location = New-Object Drawing.Point(230, 530)
$refreshButton.Size = New-Object Drawing.Size(160, 46)
$form.Controls.Add($refreshButton)

$setupButton = New-Object Windows.Forms.Button
$setupButton.Text = '运行配置向导'
$setupButton.Location = New-Object Drawing.Point(405, 530)
$setupButton.Size = New-Object Drawing.Size(160, 46)
$setupButton.BackColor = $colors.Green
$setupButton.ForeColor = [Drawing.Color]::White
$setupButton.FlatStyle = 'Flat'
$form.Controls.Add($setupButton)

$note = New-TextLabel -Text '测速会分别通过两个本地代理下载测试文件，默认总流量约 20 MB；结果受网络波动影响，不代表速度承诺。' -Size 8.5
$note.ForeColor = $colors.Muted
$note.Location = New-Object Drawing.Point(36, 595)
$form.Controls.Add($note)

$lastSnapshot = $null
$benchmarkJob = $null
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 500

function Update-Dashboard {
    param($Snapshot)
    $script:lastSnapshot = $Snapshot
    if ([bool]$Snapshot.RoutePilotPolicyActive) {
        $statusTitle.Text = '● 自动分流已启用'
        $statusTitle.ForeColor = $colors.Green
        $statusDetail.Text = 'Edge 正在使用自动分流'
    } else {
        $statusTitle.Text = '● 自动分流未启用'
        $statusTitle.ForeColor = $colors.Red
        $statusDetail.Text = 'Edge 尚未使用 RoutePilot 分流'
    }

    $primaryEndpoint.Text = "本地 HTTP 代理：$($Snapshot.Primary.Host):$($Snapshot.Primary.Port)"
    $primaryReady.Text = if ($Snapshot.Primary.Ready) { '状态：● 可以连接' } else { '状态：● 未监听' }
    $primaryReady.ForeColor = if ($Snapshot.Primary.Ready) { $colors.Green } else { $colors.Red }
    $bulkEndpoint.Text = "本地 HTTP 代理：$($Snapshot.Bulk.Host):$($Snapshot.Bulk.Port)"
    $bulkReady.Text = if ($Snapshot.Bulk.Ready) { '状态：● 可以连接' } else { '状态：● 未监听' }
    $bulkReady.ForeColor = if ($Snapshot.Bulk.Ready) { $colors.Green } else { $colors.Red }

    $primaryValue = $Snapshot.Primary.MedianMbps
    $bulkValue = $Snapshot.Bulk.MedianMbps
    $primarySpeed.Text = if ($null -eq $primaryValue) { '尚未测速' } else { "{0:N2} Mbps" -f [double]$primaryValue }
    $bulkSpeed.Text = if ($null -eq $bulkValue) { '尚未测速' } else { "{0:N2} Mbps" -f [double]$bulkValue }

    if ($null -ne $primaryValue -and $null -ne $bulkValue) {
        $maximum = [Math]::Max([double]$primaryValue, [double]$bulkValue)
        if ($maximum -le 0) { $maximum = 1 }
        $primaryBar.Value = [Math]::Max(1, [Math]::Min(100, [int][Math]::Round(([double]$primaryValue / $maximum) * 100)))
        $bulkBar.Value = [Math]::Max(1, [Math]::Min(100, [int][Math]::Round(([double]$bulkValue / $maximum) * 100)))
        $ratio = [double]$Snapshot.SpeedMultiplier
        $gainLabel.Text = "本次测试速度比例（高速线路 ÷ 主线路）：{0:N2}" -f $ratio
        $gainLabel.ForeColor = $colors.Text
    } else {
        $primaryBar.Value = 0
        $bulkBar.Value = 0
        $gainLabel.Text = '点击“开始对比测速”查看两条候选线路的差异'
        $gainLabel.ForeColor = $colors.Blue
    }
}

function Refresh-Status {
    try {
        $snapshot = & $snapshotScript -ConfigPath $ConfigPath -SkipBenchmark
        Update-Dashboard -Snapshot $snapshot
    } catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'RoutePilot 状态检查失败', 'OK', 'Error') | Out-Null
    }
}

$benchmarkButton.Add_Click({
    if ($script:benchmarkJob) { return }
    $benchmarkButton.Enabled = $false
    $benchmarkButton.Text = '正在测速…'
    $gainLabel.Text = '正在依次测试两条线路，请稍候（通常需要 10–60 秒）…'
    $gainLabel.ForeColor = $colors.Orange
    $script:benchmarkJob = Start-Job -ScriptBlock {
        param($ScriptPath, $SelectedConfig)
        & $ScriptPath -ConfigPath $SelectedConfig -Samples 2
    } -ArgumentList $snapshotScript, $ConfigPath
    $timer.Start()
})

$timer.Add_Tick({
    if (-not $script:benchmarkJob) { return }
    if ($script:benchmarkJob.State -in @('Completed', 'Failed', 'Stopped')) {
        $timer.Stop()
        try {
            if ($script:benchmarkJob.State -ne 'Completed') {
                throw "Benchmark job ended with state $($script:benchmarkJob.State)."
            }
            $snapshot = Receive-Job -Job $script:benchmarkJob -ErrorAction Stop | Select-Object -Last 1
            Update-Dashboard -Snapshot $snapshot
        } catch {
            [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'RoutePilot 测速失败', 'OK', 'Error') | Out-Null
        } finally {
            Remove-Job -Job $script:benchmarkJob -Force -ErrorAction SilentlyContinue
            $script:benchmarkJob = $null
            $benchmarkButton.Enabled = $true
            $benchmarkButton.Text = '重新对比测速'
        }
    }
})

$refreshButton.Add_Click({ Refresh-Status })
$setupButton.Add_Click({
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$setupScript`""
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments
    $statusDetail.Text = '配置向导已打开；完成后点击刷新'
})
$form.Add_FormClosing({
    $timer.Stop()
    if ($script:benchmarkJob) {
        Stop-Job -Job $script:benchmarkJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:benchmarkJob -Force -ErrorAction SilentlyContinue
    }
})

Refresh-Status
[void]$form.ShowDialog()
