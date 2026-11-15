# 新会话启动时播报汉化守护事件；标准输出必须是 JSON
$ErrorActionPreference = 'SilentlyContinue'
$EventFile = Join-Path $env:LOCALAPPDATA 'AntigravityZh\last-event.json'
[Console]::Input.ReadToEnd() | Out-Null

if (-not (Test-Path -LiteralPath $EventFile)) {
    [Console]::Out.Write('{}')
    exit 0
}

try {
    $event = Get-Content -LiteralPath $EventFile -Raw | ConvertFrom-Json
} catch {
    [Console]::Out.Write('{}')
    exit 0
}

if ($event.announced -eq $true -or -not $event.type) {
    [Console]::Out.Write('{}')
    exit 0
}

if (-not $event.message) {
    [Console]::Out.Write('{}')
    exit 0
}
$message = "【汉化守护】$($event.message) 请用一句简体中文告知用户，不要重复播报。"

$event | Add-Member -NotePropertyName announced -NotePropertyValue $true -Force
$event | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $EventFile -Encoding utf8

$payload = @{
    injectSteps = @(
        @{
            systemMessage = @{
                systemMessage = $message
            }
        }
    )
}
[Console]::Out.Write(($payload | ConvertTo-Json -Depth 6 -Compress))


