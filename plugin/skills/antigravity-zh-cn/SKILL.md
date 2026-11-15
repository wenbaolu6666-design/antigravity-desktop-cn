---
name: antigravity-zh-cn
description: 安装、修复、还原 Antigravity 简体中文界面，并检查更新守护状态。当用户说“汉化”“中文界面”“更新后又变英文”“还原英文”“汉化状态”时使用。
---

# Antigravity 中文汉化

## 边界

Antigravity 插件只能提供技能、规则和侧边栏面板，**不能直接改写宿主界面文字**。本技能负责调用仓库中的 ASAR 汉化安装器；真正生效需要关闭并重启客户端。

## 定位仓库

读取仓库路径：

```powershell
$repo = Get-Content "$env:LOCALAPPDATA\AntigravityZh\repo-path.txt" -Raw
```

若文件不存在，告诉用户先运行仓库中的 `installer\install-plugin.ps1`，或手工克隆仓库。

## 安装或修复

1. 先提醒用户保存工作：安装器会关闭并重启 Antigravity。
2. 执行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$repo\installer\install.ps1"
```

3. 安装器会自动请求管理员授权、备份原版、清理旧版本备份、写入汉化，并把修复运行时内置到插件 `runtime/`。
4. 完成后检查状态并报告版本。

## 查看状态

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$repo\installer\status.ps1"
```

## 还原英文

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$repo\installer\uninstall.ps1"
```

默认保留备份；需要彻底清理时加 `-Purge -RemovePlugin`。

## 更新检查

插件 `SessionStart` 钩子每次新会话只做一次 SHA-256 比对，**不轮询、不常驻、不注册计划任务**：

- 哈希一致：返回 `{}`，无提示。
- 哈希不一致：自动启动一次性 `runtime\auto-repair.ps1`（UAC 一次），等待客户端退出后重装；若拒绝授权，再提示用户说“修复汉化”。
- 修复：运行 `runtime\repair.ps1`（或仓库 `installer\repair.ps1`），会关闭客户端、备份、重新注入并重启。
- 修复后写入 `last-event.json`，下一次会话自动喊话确认。
- 旧版本 `app.asar.bak` 会被移除，避免降级。

## 排查

- 状态与日志：`%LOCALAPPDATA%\AntigravityZh\`（`repair.log`、`last-event.json`）
- 原版备份：`%LOCALAPPDATA%\AntigravityZh\backups\`
- 插件运行时：`~/.gemini/config/plugins/antigravity-zh-cn/runtime/`
- 若修复失败，重新运行 `installer\install.ps1`；仍失败时附上日志。


