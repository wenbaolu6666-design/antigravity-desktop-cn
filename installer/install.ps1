[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [switch]$SkipPatch,
    [switch]$SkipPlugin,
    [switch]$NoRestart,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin) -and -not $DryRun) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir)
    if ($SkipPatch) { $arguments += '-SkipPatch' }
    if ($SkipPlugin) { $arguments += '-SkipPlugin' }
    if ($NoRestart) { $arguments += '-NoRestart' }
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

if (-not $SkipPatch) {
    $repairArgs = @('-InstallDir', $InstallDir, '-NoRestart')
    if ($DryRun) { $repairArgs += '-DryRun' }
    & (Join-Path $PSScriptRoot 'repair.ps1') @repairArgs
}

if (-not $SkipPlugin) {
    & (Join-Path $PSScriptRoot 'install-plugin.ps1') -RepoRoot $RepoRoot
}

if (-not $NoRestart -and -not $SkipPatch -and -not $DryRun) {
    Start-Process -FilePath (Join-Path $InstallDir 'Antigravity.exe') | Out-Null
}

Write-Host '安装完成。' -ForegroundColor Green
Write-Host '更新检查由插件 SessionStart 事件触发：无计划任务、无后台轮询。' -ForegroundColor Cyan
Write-Host '客户端更新后，新会话会提示“修复汉化”，说一句即可重装。'
