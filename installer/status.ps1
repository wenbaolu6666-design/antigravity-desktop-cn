[CmdletBinding()]
param([string]$InstallDir = 'C:\Program Files\Antigravity')
$ErrorActionPreference = 'Stop'
$ProgramDataDir = Join-Path $env:ProgramData 'AntigravityZh'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$asar = Join-Path $InstallDir 'resources\app.asar'
$Node = 'C:\Program Files\nodejs\node.exe'
if (-not (Test-Path -LiteralPath $Node)) {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd) { $Node = $cmd.Source }
}

Write-Host '=== Antigravity 汉化状态 ===' -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $asar)) { Write-Host '未找到 Antigravity app.asar' -ForegroundColor Red; exit 1 }
$readVersion = Join-Path $ProgramDataDir 'tools\read-version.js'
if (-not (Test-Path -LiteralPath $readVersion)) { $readVersion = Join-Path $PSScriptRoot '..\tools\read-version.js' }
$version = if ((Test-Path -LiteralPath $Node) -and (Test-Path -LiteralPath $readVersion)) { (& $Node $readVersion $asar).Trim() } else { '未知' }
$bytes = [System.IO.File]::ReadAllBytes($asar)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
$patched = $text.Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')
Write-Host ("客户端版本：{0}" -f $version)
Write-Host ("界面汉化：{0}" -f $(if ($patched) { '已启用' } else { '未启用/已被更新覆盖' })) -ForegroundColor $(if ($patched) { 'Green' } else { 'Yellow' })

$task = Get-ScheduledTask -TaskName 'AntigravityZhWatcher' -ErrorAction SilentlyContinue
if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName 'AntigravityZhWatcher' -ErrorAction SilentlyContinue
    Write-Host ("更新守护：已启用（上次运行 {0}，结果 {1}）" -f $info.LastRunTime, $info.LastTaskResult) -ForegroundColor Green
} else {
    Write-Host '更新守护：未启用' -ForegroundColor Yellow
}

$eventFile = Join-Path $StateDir 'last-event.json'
if (Test-Path -LiteralPath $eventFile) {
    $event = Get-Content -LiteralPath $eventFile -Raw | ConvertFrom-Json
    Write-Host ("最近事件：{0}（{1} -> {2}）{3}" -f $event.type, $event.fromVersion, $event.toVersion, $event.message)
}

$backups = @(Get-ChildItem -LiteralPath (Join-Path $ProgramDataDir 'backups') -Filter '*.asar' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Write-Host ("原版备份：{0} 份" -f $backups.Count)
if ($backups.Count -gt 0) { Write-Host ("最新备份：{0}" -f $backups[0].FullName) -ForegroundColor DarkGray }

