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
function Start-AntigravityAsUser([string]$ExePath) {
    try {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $ExePath + '"') | Out-Null
    } catch {
        Start-Process -FilePath $ExePath | Out-Null
    }
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
    $repairScript = Join-Path $PSScriptRoot 'repair.ps1'
    if ($DryRun) {
        & $repairScript -InstallDir $InstallDir -NoRestart -DryRun
    } else {
        & $repairScript -InstallDir $InstallDir -NoRestart
    }
}

if (-not $SkipPlugin) {
    & (Join-Path $PSScriptRoot 'install-plugin.ps1') -RepoRoot $RepoRoot
}

if (-not $NoRestart -and -not $SkipPatch -and -not $DryRun) {
    Start-AntigravityAsUser (Join-Path $InstallDir 'Antigravity.exe')
}

Write-Host '安装完成。' -ForegroundColor Green
Write-Host '更新检查由插件 SessionStart 事件触发：无计划任务、无后台轮询。' -ForegroundColor Cyan
Write-Host '客户端更新后，新会话会自动启动修复；拒绝授权时也可说“修复汉化”。'


