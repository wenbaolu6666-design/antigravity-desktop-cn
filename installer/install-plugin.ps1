param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$pluginSource = Join-Path $RepoRoot 'plugin'
if (-not (Test-Path -LiteralPath $pluginSource)) { throw "未找到插件目录：$pluginSource" }
$pluginsRoot = Join-Path $env:USERPROFILE '.gemini\config\plugins'
$target = Join-Path $pluginsRoot 'antigravity-zh-cn'
New-Item -ItemType Directory -Force -Path $pluginsRoot | Out-Null
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Copy-Item -LiteralPath $pluginSource -Destination $target -Recurse -Force
$stateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
Set-Content -LiteralPath (Join-Path $stateDir 'repo-path.txt') -Value $RepoRoot -Encoding utf8
Write-Host "插件已安装：$target" -ForegroundColor Green
Write-Host '在 Antigravity 的“个性化定制 > 插件”中确认启用后，可直接对智能体说“安装/修复中文汉化”。'
