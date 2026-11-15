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

## 自动喊话

`hooks.json` 注册了 `SessionStart` 钩子：

- 更新守护完成自动重装后，会写入 `last-event.json`。
- 新会话启动时，钩子注入一条【汉化守护】系统消息，智能体会用一句中文告知用户。
- 同时守护任务会尝试弹出 Windows 通知。
