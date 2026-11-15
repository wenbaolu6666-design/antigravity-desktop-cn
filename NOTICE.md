# NOTICE

## 上游项目

本仓库是以下项目的 GitHub Fork：

- 上游：https://github.com/Silas-02/antigravity-desktop-cn
- 上游提交：`48d0227`（适配 Antigravity v2.32.1）
- 上游作者：Silas-02 及贡献者

上游仓库当前**没有 LICENSE 文件**。本仓库通过 GitHub Fork 保留完整历史与归属；上游文件的权利仍归其作者，本仓库不对其重新授权。

## 本 Fork 新增

以下内容由温保禄（GitHub: wenbaolu6666-design）新增，按 MIT 许可发布（见 `LICENSE`）：

- `installer/`：安装、状态、还原、插件安装脚本
- `watcher/watch.ps1`：客户端更新后的自动检测、备份、重装与通知
- `plugin/`：Antigravity 插件外壳（plugin.json、技能、规则、SessionStart 播报钩子）
- `tools/asar.js`、`tools/read-version.js`：ASAR 读取与版本检测
- `localization_engine.js` 中新增的：
  - `getToolActivityStatusTranslation`：活动流状态词翻译
  - `getHomeGreetingTranslation`：首页问候语翻译
- 本 Fork 的中文文档与 README 增补

## 安全说明

- 安装器会请求管理员权限，因为它需要替换 `C:\Program Files\Antigravity\resources\app.asar` 并注册计划任务。
- 更新守护任务以当前用户身份运行，使用最高权限，每 10 分钟检查一次；脚本固定安装到 `C:\ProgramData\AntigravityZh`，避免执行用户可写目录中的代码。
- 安装前会把官方 `app.asar` 备份到 `C:\ProgramData\AntigravityZh\backups`。
