[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [switch]$Purge,
    [switch]$RemovePlugin,
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
$ProgramDataDir = Join-Path $env:ProgramData 'AntigravityZh'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$asar = Join-Path $InstallDir 'resources\app.asar'
$bak = Join-Path $InstallDir 'resources\app.asar.bak'

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir)
    if ($Purge) { $arguments += '-Purge' }
    if ($RemovePlugin) { $arguments += '-RemovePlugin' }
    if ($NoRestart) { $arguments += '-NoRestart' }
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

Unregister-ScheduledTask -TaskName 'AntigravityZhWatcher' -Confirm:$false -ErrorAction SilentlyContinue

Get-Process Antigravity -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.MainWindowHandle -ne 0) { $_.CloseMainWindow() | Out-Null }
}
Start-Sleep -Seconds 4
Get-Process Antigravity -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$Node = 'C:\Program Files\nodejs\node.exe'
if (-not (Test-Path -LiteralPath $Node)) { $Node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source }
$version = if ($Node) { (& $Node (Join-Path $ProgramDataDir 'tools\read-version.js') $asar).Trim() } else { '' }

$restored = $false
$backup = Get-ChildItem -LiteralPath (Join-Path $ProgramDataDir 'backups') -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($backup) {
    Copy-Item -LiteralPath $backup.FullName -Destination $asar -Force
    $restored = $true
    Write-Host "已从备份还原：$($backup.FullName)" -ForegroundColor Green
} elseif (Test-Path -LiteralPath $bak) {
    Copy-Item -LiteralPath $bak -Destination $asar -Force
    $restored = $true
    Write-Host '已从 app.asar.bak 还原。' -ForegroundColor Green
}

if (-not $restored) { Write-Host '未找到可用备份，app.asar 未改动。' -ForegroundColor Yellow }
if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue }

if ($RemovePlugin) {
    $pluginDir = Join-Path $env:USERPROFILE '.gemini\config\plugins\antigravity-zh-cn'
    if (Test-Path -LiteralPath $pluginDir) { Remove-Item -LiteralPath $pluginDir -Recurse -Force }
    Write-Host '已移除 Antigravity 插件外壳。' -ForegroundColor Green
}

if ($Purge) {
    $target = [System.IO.Path]::GetFullPath($ProgramDataDir)
    $expected = [System.IO.Path]::GetFullPath((Join-Path $env:ProgramData 'AntigravityZh'))
    if ($target -eq $expected -and (Test-Path -LiteralPath $target)) {
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host '已清理 ProgramData 下的守护组件与备份。' -ForegroundColor Green
    }
}

if (-not $NoRestart -and $restored) {
    Start-Process -FilePath (Join-Path $InstallDir 'Antigravity.exe') | Out-Null
}
Write-Host '还原流程结束。' -ForegroundColor Cyan
