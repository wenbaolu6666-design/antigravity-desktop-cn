[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [switch]$Purge,
    [switch]$RemovePlugin,
    [switch]$NoRestart
)
$ErrorActionPreference = 'Stop'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$PluginDir = Join-Path $env:USERPROFILE '.gemini\config\plugins\antigravity-zh-cn'
$asar = Join-Path $InstallDir 'resources\app.asar'
$bak = Join-Path $InstallDir 'resources\app.asar.bak'

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
$readVersion = Join-Path $PluginDir 'runtime\tools\read-version.js'
if (-not (Test-Path -LiteralPath $readVersion)) { $readVersion = Join-Path $PSScriptRoot '..\tools\read-version.js' }
$version = if ((Test-Path -LiteralPath $Node) -and (Test-Path -LiteralPath $readVersion)) { (& $Node $readVersion $asar).Trim() } else { '' }

$restored = $false
$backup = Get-ChildItem -LiteralPath (Join-Path $StateDir 'backups') -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $backup) {
    $legacyDir = Join-Path $env:ProgramData 'AntigravityZh\backups'
    $backup = Get-ChildItem -LiteralPath $legacyDir -Filter "app-$version-*.asar" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
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

if ($RemovePlugin -and (Test-Path -LiteralPath $PluginDir)) {
    Remove-Item -LiteralPath $PluginDir -Recurse -Force
    Write-Host '已移除 Antigravity 插件外壳与内置运行时。' -ForegroundColor Green
}

if ($Purge) {
    foreach ($dir in @($StateDir, (Join-Path $env:ProgramData 'AntigravityZh'))) {
        if (Test-Path -LiteralPath $dir) {
            $full = [System.IO.Path]::GetFullPath($dir)
            $allowed = @(
                [System.IO.Path]::GetFullPath($StateDir),
                [System.IO.Path]::GetFullPath((Join-Path $env:ProgramData 'AntigravityZh'))
            )
            if ($allowed -contains $full) { Remove-Item -LiteralPath $full -Recurse -Force; Write-Host "已清理：$full" -ForegroundColor Green }
        }
    }
}

if (-not $NoRestart -and $restored) {
    Start-AntigravityAsUser (Join-Path $InstallDir 'Antigravity.exe')
}
Write-Host '还原流程结束。' -ForegroundColor Cyan
