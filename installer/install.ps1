[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [switch]$SkipPatch,
    [switch]$SkipWatcher,
    [switch]$SkipPlugin,
    [switch]$NoRestart,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ProgramDataDir = Join-Path $env:ProgramData 'AntigravityZh'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$WatcherTask = 'AntigravityZhWatcher'
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

if (-not (Test-Admin) -and -not $DryRun) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir)
    foreach ($name in 'SkipPatch', 'SkipWatcher', 'SkipPlugin', 'NoRestart') {
        if ((Get-Variable $name -ValueOnly)) { $arguments += "-$name" }
    }
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

$asar = Join-Path $InstallDir 'resources\app.asar'
if (-not (Test-Path -LiteralPath $asar)) { throw "未找到 Antigravity：$asar" }

New-Item -ItemType Directory -Force -Path $ProgramDataDir, (Join-Path $ProgramDataDir 'backups'), (Join-Path $ProgramDataDir 'logs'), $StateDir | Out-Null

# 将运行所需文件安装到 ProgramData，避免计划任务执行用户可写目录中的脚本
foreach ($item in 'localization_engine.js', 'dicts', 'tools', 'watcher') {
    $source = Join-Path $RepoRoot $item
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $ProgramDataDir -Recurse -Force
    }
}

$version = (& $Node (Join-Path $ProgramDataDir 'tools\read-version.js') $asar).Trim()
if (-not $version) { throw '无法读取 Antigravity 版本号。' }

$bak = Join-Path $InstallDir 'resources\app.asar.bak'
$currentBytes = [System.IO.File]::ReadAllBytes($asar)
$currentPatched = ([System.Text.Encoding]::UTF8.GetString($currentBytes)).Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')
$backupSource = $asar
if ($currentPatched) {
    if (Test-Path -LiteralPath $bak) {
        $bakVersion = (& $Node (Join-Path $ProgramDataDir 'tools\read-version.js') $bak).Trim()
        if ($bakVersion -eq $version) {
            $backupSource = $bak
            Write-Host '检测到当前已是汉化版，将从 app.asar.bak 备份官方原版。' -ForegroundColor DarkGray
        }
    }
    if ($backupSource -eq $asar) {
        Write-Host '警告：当前是汉化版且找不到同版本官方备份，无法生成可靠的原版备份。' -ForegroundColor Yellow
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $ProgramDataDir "backups\app-$version-$stamp.asar"
Copy-Item -LiteralPath $backupSource -Destination $backup -Force
Write-Host "已备份原版：$backup" -ForegroundColor DarkGray

# 避免旧版本备份被引擎当作源文件，造成降级
if (Test-Path -LiteralPath $bak) {
    $bakVersion = (& $Node (Join-Path $ProgramDataDir 'tools\read-version.js') $bak).Trim()
    if ($bakVersion -ne $version) {
        Remove-Item -LiteralPath $bak -Force
        Write-Host "已移除旧版本备份（$bakVersion），防止降级。" -ForegroundColor Yellow
    }
}

if (-not $SkipPatch) {
    Write-Host '正在关闭 Antigravity 并写入汉化...' -ForegroundColor Cyan
    Get-Process Antigravity -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.MainWindowHandle -ne 0) { $_.CloseMainWindow() | Out-Null }
    }
    Start-Sleep -Seconds 4
    Get-Process Antigravity -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    & $Node (Join-Path $ProgramDataDir 'localization_engine.js') --install-dir $InstallDir --no-kill --brand-title english
    if ($LASTEXITCODE -ne 0) { throw "汉化引擎退出码：$LASTEXITCODE" }

    $bytes = [System.IO.File]::ReadAllBytes($asar)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if (-not $text.Contains('__ANTIGRAVITY_CHINESE_LOCALIZATION_START__')) {
        throw '写入完成但未检测到汉化标记，请检查日志。'
    }
    $version = (& $Node (Join-Path $ProgramDataDir 'tools\read-version.js') $asar).Trim()
}

if (-not $SkipWatcher) {
    $watcherScript = Join-Path $ProgramDataDir 'watcher\watch.ps1'
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watcherScript`""
    $logon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $repeat = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) -RepetitionInterval (New-TimeSpan -Minutes 10)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $WatcherTask -Action $action -Trigger @($logon, $repeat) -Principal $principal -Force | Out-Null
    Write-Host "已启用更新守护计划任务：$WatcherTask（每 10 分钟检查一次）" -ForegroundColor Green
}

$state = [ordered]@{
    version = $version
    patchedAt = (Get-Date).ToString('o')
    installDir = $InstallDir
    backup = $backup
    watcherTask = $WatcherTask
    watcherEnabled = -not $SkipWatcher
}
$state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ProgramDataDir 'state.json') -Encoding utf8

if (-not $SkipPlugin) {
    & (Join-Path $PSScriptRoot 'install-plugin.ps1') -RepoRoot $RepoRoot
}

if (-not $NoRestart -and -not $SkipPatch) {
    Start-Process -FilePath (Join-Path $InstallDir 'Antigravity.exe') | Out-Null
}

Write-Host "汉化安装完成：Antigravity $version" -ForegroundColor Green

