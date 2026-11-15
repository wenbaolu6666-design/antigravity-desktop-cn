# 会话启动时检查补丁哈希并播报；不做轮询、不启动后台进程
$ErrorActionPreference = 'SilentlyContinue'
[Console]::Input.ReadToEnd() | Out-Null

$stateDir = Join-Path $env:LOCALAPPDATA 'AntigravityZh'
$stateFile = Join-Path $stateDir 'state.json'
$eventFile = Join-Path $stateDir 'last-event.json'
$messages = New-Object System.Collections.Generic.List[string]

$state = $null
if (Test-Path -LiteralPath $stateFile) {
    try { $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json } catch {}
}

$asar = 'C:\Program Files\Antigravity\resources\app.asar'
if ($state -and $state.installDir) { $asar = Join-Path $state.installDir 'resources\app.asar' }

$needsRepair = $false
if (-not $state) {
    $needsRepair = $true
} elseif (-not (Test-Path -LiteralPath $asar)) {
    $needsRepair = $true
} else {
    $hash = (Get-FileHash -LiteralPath $asar -Algorithm SHA256).Hash
    if (-not $state.patchedHash -or $hash -ne $state.patchedHash) { $needsRepair = $true }
}

if ($needsRepair) {
    $autoRepair = Join-Path $PSScriptRoot '..\runtime\auto-repair.ps1'
    $spawned = $false
    if ((Test-Path -LiteralPath $autoRepair) -and $env:ANTIGRAVITY_ZH_NO_AUTO_REPAIR -ne '1') {
        try {
            $existing = Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*auto-repair.ps1*' }
            if ($existing) {
                $spawned = $true
            } else {
                Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $autoRepair | Out-Null
                $spawned = $true
            }
        } catch {}
    }
    if ($spawned) {
        $messages.Add('【汉化守护】检测到 Antigravity 已更新，已启动自动修复；退出客户端后会自动重装汉化。请用一句简体中文告知用户。')
    } else {
        $messages.Add('【汉化守护】检测到 Antigravity 已更新或汉化被覆盖。请用一句简体中文提醒用户说“修复汉化”。')
    }
} elseif (Test-Path -LiteralPath $eventFile) {
    try {
        $event = Get-Content -LiteralPath $eventFile -Raw | ConvertFrom-Json
        if ($event.announced -ne $true -and $event.message) {
            $messages.Add("【汉化守护】$($event.message) 请用一句简体中文告知用户，不要重复播报。")
            $event | Add-Member -NotePropertyName announced -NotePropertyValue $true -Force
            $event | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventFile -Encoding utf8
        }
    } catch {}
}

if ($messages.Count -eq 0) {
    [Console]::Out.Write('{}')
    exit 0
}

$payload = @{
    injectSteps = @(
        @{
            systemMessage = @{
                systemMessage = ($messages -join "`n")
            }
        }
    )
}
[Console]::Out.Write(($payload | ConvertTo-Json -Depth 6 -Compress))

