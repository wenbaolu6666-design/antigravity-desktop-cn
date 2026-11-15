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

3. 安装器会自动请求管理员授权、备份原版、清理旧版本备份、写入汉化并注册更新守护任务。
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

## 更新守护

安装器会注册计划任务 `AntigravityZhWatcher`，每 10 分钟检查一次：

- 客户端更新后，`app.asar` 会被官方替换，汉化标记消失。
- 守护任务检测到新版本后，会在客户端退出时自动重新注入汉化。
- 重新注入后会写入 `%LOCALAPPDATA%\AntigravityZh\last-event.json`，并通过新会话系统消息播报；同时尝试弹出 Windows 通知。
- 旧版本 `app.asar.bak` 会被移除，避免把旧包体写回新版本。

## 排查

- 日志：`C:\ProgramData\AntigravityZh\logs\`
- 引擎输出：`C:\ProgramData\AntigravityZh\logs\engine.log`
- 原版备份：`C:\ProgramData\AntigravityZh\backups\`
- 若自动重装失败，重新运行 `installer\install.ps1`；仍失败时附上日志。
