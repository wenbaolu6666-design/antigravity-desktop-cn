param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$pluginSource = Join-Path $RepoRoot 'plugin'
if (-not (Test-Path -LiteralPath $pluginSource)) { throw "未找到插件目录：$pluginSource" }
$pluginsRoot = Join-Path $env:USERPROFILE '.gemini\config\plugins'
$target = Join-Path $pluginsRoot 'antigravity-zh-cn'
New-Item -ItemType Directory -Force -Path $pluginsRoot | Out-Null
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Copy-Item -LiteralPath $pluginSource -Destination $target -Recurse -Force

# 把修复运行时内置到插件，更新后无需外部目录
$runtime = Join-Path $target 'runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
Copy-Item -LiteralPath (Join-Path $RepoRoot 'localization_engine.js') -Destination $runtime -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'dicts') -Destination $runtime -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'tools') -Destination $runtime -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'installer\repair.ps1') -Destination $runtime -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot 'installer\auto-repair.ps1') -Destination $runtime -Force

$stateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
Set-Content -LiteralPath (Join-Path $stateDir 'repo-path.txt') -Value $RepoRoot -Encoding utf8
Write-Host "插件已安装：$target" -ForegroundColor Green
Write-Host '运行时已内置到插件 runtime/；更新检查由 SessionStart 钩子完成。'

