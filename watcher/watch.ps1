[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [string]$ProgramDataDir = (Join-Path $env:ProgramData 'AntigravityZh'),
    [string]$StateDir = (Join-Path $env:LOCALAPPDATA 'AntigravityZh'),
    [switch]$DryRun,
    [switch]$Force,
    [switch]$IgnoreRunning
)

$ErrorActionPreference = 'Stop'
$LogDir = Join-Path $ProgramDataDir 'logs'
$StateFile = Join-Path $ProgramDataDir 'state.json'
$EventFile = Join-Path $StateDir 'last-event.json'
$WatcherTask = 'AntigravityZhWatcher'
New-Item -ItemType Directory -Force -Path $StateDir, $LogDir, (Join-Path $ProgramDataDir 'backups') | Out-Null

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath (Join-Path $LogDir ("watch-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))) -Value $line -Encoding utf8
}

function Show-Notice([string]$Title, [string]$Text) {
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $icon = New-Object System.Windows.Forms.NotifyIcon
        $icon.Icon = [System.Drawing.SystemIcons]::Information
        $icon.Visible = $true
        $icon.ShowBalloonTip(8000, $Title, $Text, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Seconds 2
        $icon.Dispose()
    } catch {}
    try { msg.exe $env:USERNAME "$Title`n$Text" | Out-Null } catch {}
}

function Set-Event([string]$Type, [string]$FromVersion, [string]$ToVersion, [string]$Message) {
    $payload = [ordered]@{
        type = $Type
        fromVersion = $FromVersion
        toVersion = $ToVersion
        message = $Message
        at = (Get-Date).ToString('o')
        announced = $false
    }
    $payload | ConvertTo-Json | Set-Content -LiteralPath $EventFile -Encoding utf8
}

function Get-State {
    if (Test-Path -LiteralPath $StateFile) {
        try { return Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json } catch {}
    }
    return $null
}

$asar = Join-Path $InstallDir 'resources\app.asar'
if (-not (Test-Path -LiteralPath $asar)) { Write-Log "未找到 $asar"; exit 0 }

$Node = 'C:\Program Files\nodejs\node.exe'
if (-not (Test-Path -LiteralPath $Node)) {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $cmd) { Write-Log '未找到 Node.js'; exit 1 }
    $Node = $cmd.Source
}
$readVersion = Join-Path $ProgramDataDir 'tools\read-version.js'
$engine = Join-Path $ProgramDataDir 'localization_engine.js'
if (-not (Test-Path -LiteralPath $readVersion) -or -not (Test-Path -LiteralPath $engine)) {
    Write-Log '守护组件不完整，请重新运行 installer\install.ps1'
    exit 1
}

$version = (& $Node $readVersion $asar).Trim()
if (-not $version) { Write-Log '无法读取版本号'; exit 1 }

$bytes = [System.IO.File]::ReadAllBytes($asar)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
$patched = $text.Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')
$running = if ($IgnoreRunning) { $false } else { [bool](Get-Process Antigravity -ErrorAction SilentlyContinue) }
$state = Get-State
$stateVersion = if ($state) { $state.version } else { '' }

if ($patched -and $version -eq $stateVersion -and -not $Force) { exit 0 }

if ($running) {
    if ($version -ne $stateVersion) {
        Write-Log "检测到 Antigravity $version，客户端正在运行，等待退出后重装汉化"
        Set-Event 'pending' $stateVersion $version "检测到 Antigravity $version，退出客户端后将自动重装汉化。"
        Show-Notice '汉化守护' "检测到 Antigravity $version，退出客户端后将自动重装汉化。"
    }
    exit 0
}

Write-Log "开始处理：版本 $version，已汉化=$patched，上次版本=$stateVersion"
if ($DryRun) { Write-Log 'DryRun：跳过写入'; exit 0 }

try {
    $existing = @(Get-ChildItem -LiteralPath (Join-Path $ProgramDataDir 'backups') -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue)
    if ($existing.Count -eq 0) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $asar -Destination (Join-Path $ProgramDataDir "backups\app-$version-$stamp.asar") -Force
    }

    $bak = Join-Path $InstallDir 'resources\app.asar.bak'
    if (Test-Path -LiteralPath $bak) {
        $bakVersion = (& $Node $readVersion $bak).Trim()
        if ($bakVersion -ne $version) {
            Remove-Item -LiteralPath $bak -Force
            Write-Log "已移除旧版本备份 $bakVersion，避免降级"
        }
    }

    & $Node $engine --install-dir $InstallDir --no-kill --brand-title english *>> (Join-Path $LogDir 'engine.log')
    if ($LASTEXITCODE -ne 0) { throw "汉化引擎退出码 $LASTEXITCODE" }

    $bytes = [System.IO.File]::ReadAllBytes($asar)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if (-not $text.Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')) { throw '未检测到汉化标记' }

    $payload = [ordered]@{
        version = $version
        patchedAt = (Get-Date).ToString('o')
        installDir = $InstallDir
        watcherTask = $WatcherTask
        watcherEnabled = $true
    }
    $payload | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding utf8
    $message = if ($stateVersion -eq $version) { "Antigravity $version 的汉化补丁已重新应用。" } else { "Antigravity 已更新到 $version，汉化已自动重装。" }
    Set-Event 'relocalized' $stateVersion $version $message
    Show-Notice '汉化已自动更新' "Antigravity $version 的汉化已重装完成。"
    Write-Log "完成：$version 汉化已重装"
}
catch {
    Write-Log "失败：$($_.Exception.Message)"
    Set-Event 'failed' $stateVersion $version "汉化自动重装失败：$($_.Exception.Message)"
    Show-Notice '汉化自动更新失败' "请打开 AntigravityZh 日志或重新运行 installer\install.ps1。"
    exit 1
}





