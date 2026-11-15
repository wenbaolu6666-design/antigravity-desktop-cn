[CmdletBinding()]
param([string]$InstallDir = 'C:\Program Files\Antigravity')
$ErrorActionPreference = 'Stop'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$PluginDir = Join-Path $env:USERPROFILE '.gemini\config\plugins\antigravity-zh-cn'
$asar = Join-Path $InstallDir 'resources\app.asar'
Write-Host '=== Antigravity 汉化状态 ===' -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $asar)) { Write-Host '未找到 Antigravity app.asar' -ForegroundColor Red; exit 1 }

$readVersion = Join-Path $PluginDir 'runtime\tools\read-version.js'
if (-not (Test-Path -LiteralPath $readVersion)) { $readVersion = Join-Path $PSScriptRoot '..\tools\read-version.js' }
$Node = 'C:\Program Files\nodejs\node.exe'
if (-not (Test-Path -LiteralPath $Node)) { $Node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source }
$version = if ((Test-Path -LiteralPath $Node) -and (Test-Path -LiteralPath $readVersion)) { (& $Node $readVersion $asar).Trim() } else { '未知' }
$bytes = [System.IO.File]::ReadAllBytes($asar)
$patched = ([System.Text.Encoding]::UTF8.GetString($bytes)).Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')
Write-Host ("客户端版本：{0}" -f $version)
Write-Host ("界面汉化：{0}" -f $(if ($patched) { '已启用' } else { '未启用/已被更新覆盖' })) -ForegroundColor $(if ($patched) { 'Green' } else { 'Yellow' })

$stateFile = Join-Path $StateDir 'state.json'
if (Test-Path -LiteralPath $stateFile) {
    $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $hash = (Get-FileHash -LiteralPath $asar -Algorithm SHA256).Hash
    $match = $state.patchedHash -and $hash -eq $state.patchedHash
    Write-Host ("补丁校验：{0}" -f $(if ($match) { '与上次安装一致' } else { '已变化，需要修复' })) -ForegroundColor $(if ($match) { 'Green' } else { 'Yellow' })
    Write-Host ("上次安装：{0}" -f $state.patchedAt)
} else {
    Write-Host '补丁校验：未找到安装状态' -ForegroundColor Yellow
}

$legacyTask = Get-ScheduledTask -TaskName 'AntigravityZhWatcher' -ErrorAction SilentlyContinue
Write-Host ("后台计划任务：{0}" -f $(if ($legacyTask) { '仍存在（旧版残留，建议卸载重装）' } else { '无（插件 SessionStart 事件检查）' })) -ForegroundColor $(if ($legacyTask) { 'Yellow' } else { 'Green' })

$eventFile = Join-Path $StateDir 'last-event.json'
if (Test-Path -LiteralPath $eventFile) {
    $event = Get-Content -LiteralPath $eventFile -Raw | ConvertFrom-Json
    Write-Host ("最近事件：{0}（{1} -> {2}）{3}" -f $event.type, $event.fromVersion, $event.toVersion, $event.message)
}
$backups = @(Get-ChildItem -LiteralPath (Join-Path $StateDir 'backups') -Filter '*.asar' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Write-Host ("原版备份：{0} 份" -f $backups.Count)
if ($backups.Count -gt 0) { Write-Host ("最新备份：{0}" -f $backups[0].FullName) -ForegroundColor DarkGray }
Write-Host ("插件运行时：{0}" -f $(if (Test-Path -LiteralPath (Join-Path $PluginDir 'runtime\localization_engine.js')) { '已内置' } else { '缺失' }))
