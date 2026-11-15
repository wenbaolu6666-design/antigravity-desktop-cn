[CmdletBinding()]
param(
    [string]$InstallDir = 'C:\Program Files\Antigravity',
    [int]$TimeoutMinutes = 120,
    [switch]$SkipElevation,
    [switch]$IgnoreRunning
)
$ErrorActionPreference = 'Stop'
$StateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$log = Join-Path $StateDir 'auto-repair.log'

function Write-Log([string]$Message) {
    Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding utf8
}

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin) -and -not $SkipElevation) {
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $PSCommandPath, '-InstallDir', $InstallDir, '-TimeoutMinutes', $TimeoutMinutes | Out-Null
    exit
}

$repair = Join-Path $PSScriptRoot 'repair.ps1'
if (-not (Test-Path -LiteralPath $repair)) { Write-Log "缺少 repair.ps1：$PSScriptRoot"; exit 1 }

Write-Log '自动修复已启动，等待 Antigravity 退出'
if (-not $IgnoreRunning) {
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Process Antigravity -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
    }
    if (Get-Process Antigravity -ErrorAction SilentlyContinue) {
        Write-Log "等待超时（$TimeoutMinutes 分钟），客户端仍在运行，已退出"
        exit 0
    }
}

try {
    & $repair -InstallDir $InstallDir -SkipElevation -IgnoreRunning
    Write-Log '自动修复完成'
}
catch {
    Write-Log "自动修复失败：$($_.Exception.Message)"
    exit 1
}

