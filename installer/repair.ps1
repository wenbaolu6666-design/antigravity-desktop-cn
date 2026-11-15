[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [switch]$NoRestart,
    [switch]$DryRun,
    [switch]$SkipElevation,
    [switch]$IgnoreRunning
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = if (Test-Path -LiteralPath (Join-Path $RepoRoot 'localization_engine.js')) { $RepoRoot } else { $PSScriptRoot }
$Engine = Join-Path $RuntimeDir 'localization_engine.js'
$ReadVersion = Join-Path $RuntimeDir 'tools\read-version.js'
if (-not (Test-Path -LiteralPath $Engine) -or -not (Test-Path -LiteralPath $ReadVersion)) {
    throw "汉化运行时缺失：$RuntimeDir"
}

$Node = 'C:\Program Files\nodejs\node.exe'
if (-not (Test-Path -LiteralPath $Node)) {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $cmd) { throw '未找到 Node.js，请先安装 Node.js LTS。' }
    $Node = $cmd.Source
}

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Start-AntigravityAsUser([string]$ExePath) {
    try {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $ExePath + '"') | Out-Null
    } catch {
        Start-Process -FilePath $ExePath | Out-Null
    }
}

if (-not (Test-Admin) -and -not $DryRun -and -not $SkipElevation) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir)
    if ($NoRestart) { $arguments += '-NoRestart' }
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$BackupDir = Join-Path $StateDir 'backups'
$StateFile = Join-Path $StateDir 'state.json'
$EventFile = Join-Path $StateDir 'last-event.json'
New-Item -ItemType Directory -Force -Path $StateDir, $BackupDir | Out-Null

# 迁移旧版本的 ProgramData 备份，并清理旧计划任务
$legacyBackupDir = Join-Path $env:ProgramData 'AntigravityZh\backups'
Unregister-ScheduledTask -TaskName 'AntigravityZhWatcher' -Confirm:$false -ErrorAction SilentlyContinue

$asar = Join-Path $InstallDir 'resources\app.asar'
if (-not (Test-Path -LiteralPath $asar)) { throw "未找到 Antigravity：$asar" }
$version = (& $Node $ReadVersion $asar).Trim()
if (-not $version) { throw '无法读取 Antigravity 版本号。' }

$oldState = $null
if (Test-Path -LiteralPath $StateFile) {
    try { $oldState = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json } catch {}
}

$bak = Join-Path $InstallDir 'resources\app.asar.bak'
$currentBytes = [System.IO.File]::ReadAllBytes($asar)
$currentPatched = ([System.Text.Encoding]::UTF8.GetString($currentBytes)).Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')
$backupSource = $asar
if ($currentPatched -and (Test-Path -LiteralPath $bak)) {
    $bakVersion = (& $Node $ReadVersion $bak).Trim()
    if ($bakVersion -eq $version) { $backupSource = $bak }
}

$hasBackup = @(Get-ChildItem -LiteralPath $BackupDir -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue).Count -gt 0
if (-not $hasBackup -and (Test-Path -LiteralPath $legacyBackupDir)) {
    $legacy = Get-ChildItem -LiteralPath $legacyBackupDir -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($legacy) { Copy-Item -LiteralPath $legacy.FullName -Destination $BackupDir -Force; $hasBackup = $true }
}
$backup = $null
if (-not $hasBackup) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = Join-Path $BackupDir "app-$version-$stamp.asar"
    Copy-Item -LiteralPath $backupSource -Destination $backup -Force
} else {
    $backup = (Get-ChildItem -LiteralPath $BackupDir -Filter "app-$version-*.asar" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

if (Test-Path -LiteralPath $bak) {
    $bakVersion = (& $Node $ReadVersion $bak).Trim()
    if ($bakVersion -ne $version) {
        Remove-Item -LiteralPath $bak -Force
        Write-Host "已移除旧版本备份（$bakVersion），防止降级。" -ForegroundColor Yellow
    }
}

if ($DryRun) { Write-Host 'DryRun：跳过关闭与写入。' -ForegroundColor Yellow; exit 0 }

if (-not $IgnoreRunning) {
    Get-Process Antigravity -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.MainWindowHandle -ne 0) { $_.CloseMainWindow() | Out-Null }
    }
    Start-Sleep -Seconds 4
    Get-Process Antigravity -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$log = Join-Path $StateDir 'repair.log'
& $Node $Engine --install-dir $InstallDir --no-kill --brand-title english *>> $log
if ($LASTEXITCODE -ne 0) { throw "汉化引擎退出码：$LASTEXITCODE（日志：$log）" }

$bytes = [System.IO.File]::ReadAllBytes($asar)
if (-not ([System.Text.Encoding]::UTF8.GetString($bytes)).Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')) {
    throw '写入完成但未检测到汉化标记。'
}
$patchedHash = (Get-FileHash -LiteralPath $asar -Algorithm SHA256).Hash
$state = [ordered]@{
    version = $version
    patchedAt = (Get-Date).ToString('o')
    installDir = $InstallDir
    patchedHash = $patchedHash
    backup = $backup
    mode = 'plugin-hook'
}
$state | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding utf8

$oldVersion = if ($oldState) { $oldState.version } else { '' }
$message = if (-not $oldVersion) { "Antigravity $version 的汉化已安装完成。" } elseif ($oldVersion -eq $version) { "Antigravity $version 的汉化补丁已重新应用。" } else { "Antigravity 已更新到 $version，汉化已重新应用。" }
$event = [ordered]@{
    type = 'relocalized'
    fromVersion = $oldVersion
    toVersion = $version
    message = $message
    at = (Get-Date).ToString('o')
    announced = $false
}
$event | ConvertTo-Json | Set-Content -LiteralPath $EventFile -Encoding utf8

if (-not $NoRestart) { Start-AntigravityAsUser (Join-Path $InstallDir 'Antigravity.exe') }
Write-Host "汉化修复完成：Antigravity $version" -ForegroundColor Green


