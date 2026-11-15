# 反重力中文汉化插件（外壳）

> Antigravity 插件只能提供**技能、规则和侧边栏面板**，不能直接改写宿主界面文字。
> 本插件是汉化工具的“对话入口”和“状态播报器”；真正改写界面依赖仓库中的 ASAR 补丁与客户端重启。

## 安装插件

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\installer\install-plugin.ps1
```

脚本会把本目录复制到：

```text
%USERPROFILE%\.gemini\config\plugins\antigravity-zh-cn\
```

并在 `%LOCALAPPDATA%\AntigravityZh\repo-path.txt` 写入仓库路径，供技能定位安装器。

重启 Antigravity 后，在“个性化定制 > 插件”中确认 `反重力中文汉化` 已启用。

## 使用

在反重力对话中直接说：

- “安装中文汉化”
- “更新后又变英文了，修复一下”
- “查看汉化状态”
- “还原英文”

智能体会调用 `installer\install.ps1` / `status.ps1` / `uninstall.ps1`。

## 更新检查与自动喊话

`hooks.json` 注册了 `SessionStart` 钩子，每次新会话只做一次 SHA-256 比对，**不轮询、不常驻、不注册计划任务**：

- 哈希一致：返回 `{}`，不产生提示。
- 哈希不一致：注入【汉化守护】消息，提示用户说“修复汉化”。
- 修复完成：写入 `last-event.json`，下一次会话自动喊话确认。
- 修复运行时已内置在 `runtime/`，不依赖 ProgramData 或外部守护进程。

