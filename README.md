# Antigravity 简体中文汉化（插件版）

> 本仓库 Fork 自 [Silas-02/antigravity-desktop-cn](https://github.com/Silas-02/antigravity-desktop-cn)，在 v2.32.1 汉化基础上新增：
> **插件外壳、更新后自动重装、自动喊话、独立备份、安装/还原/状态脚本**。

## 一键安装（Windows）

```powershell
git clone https://github.com/wenbaolu6666-design/antigravity-desktop-cn.git
cd antigravity-desktop-cn
pwsh -NoProfile -ExecutionPolicy Bypass -File .\installer\install.ps1
```

安装器会：

1. 请求一次管理员授权；
2. 备份官方 `app.asar` 到 `C:\ProgramData\AntigravityZh\backups`；
3. 清理旧版本 `app.asar.bak`，避免客户端升级后被旧包体降级；
4. 关闭并重启 Antigravity，写入汉化；
5. 安装插件外壳，并把修复运行时内置到插件的 `runtime/`；不注册计划任务、不常驻后台；
6. 在插件 `SessionStart` 时用补丁哈希检查更新。

## 源码级汉化（外部 web bundle）

Antigravity 的 UI 实际由 `language_server.exe` 内嵌的 ZIP 提供，其中包含完整的 `main.js`。本项目利用 `language_server.exe -web_bundle_path` 参数，把完整前端解包到：

```text
%LOCALAPPDATA%\AntigravityZh\web
```

安装/修复时会：

1. 从当前 `language_server.exe` 定位并解包内嵌 ZIP；
2. 用 AST 只替换 React 文本与 UI 属性（保留 `${变量}`、路径、命令和代码）；
3. 生成源码级中文 `main.js`，并写入 `.web-bundle-ok` 标记；
4. 在 `app.asar` 的 `lsDefaults.js` 中注入 `--web_bundle_path`，让客户端优先加载外部 bundle。

客户端更新后，修复助手会从**新版本的** `language_server.exe` 重新解包、重新翻译、重新生成 bundle，因此更新不会把汉化永久覆盖。少量服务端动态文案仍由运行时翻译兜底。源码翻译会自动跳过 protobuf、SVG `transform`、URL、路径等技术字符串，避免破坏初始化或图形。自动生成的工作区名（如 `Codex Session Import`）只在侧栏显示层翻译，不改真实数据。
## 关于管理员控制台窗口

安装器需要管理员权限写入 `app.asar`，但**重启客户端时会通过 `explorer.exe` 以当前登录用户身份启动**，不会让 Antigravity 继承管理员令牌，也不会留下显示启动日志的 Administrator 控制台窗口。
## 更新后的处理（插件事件检查）

Antigravity 更新会替换 `app.asar`。插件在每次新会话启动时只做一次 SHA-256 比对，**不轮询、不常驻、不注册计划任务**：

- 哈希与上次安装一致：直接返回，不产生提示；
- 哈希不一致：启动一次性提权修复助手 `runtime/auto-repair.ps1`（UAC 一次），并注入【汉化守护】消息；
- 修复助手等待 Antigravity 退出后，自动备份、重新注入并以普通用户身份重启；
- 若拒绝授权，消息会提示说“修复汉化”，由 `runtime/repair.ps1` 手动修复；
- 完成后写入 `last-event.json`，下一次会话自动喊话确认。
旧版本备份不会被写回新版本，避免版本错配。

## 动态文案

- 首页问候语按当前登录用户名动态生成，**不写死任何姓名**。
- 思考等级只在模型选择器内翻译为 `低/中/高/极高/最高`，模型名里的 `High/Medium` 保持原样。
- 模型可用性通知覆盖 `currently/now available`、`subscribers/plans`、`available only to`、`currently unavailable` 等句式，并保留模型名与日期。
- 智能体活动流补充 `Canceled/Cancelled`、`Killed`、`Checked`、`Created`、`Started`、`Stopped`、`Completed`、`Failed` 等动词，以及 `search/task/run/subagent/command/file` 等宾语；`$Qc`、文件名、扩展名与 `+10 -0` 计数保持原样。
- “思考”块正文支持按需显示中文译文：仅在展开且文本稳定后，将纯英文段落批量发送到 Google 翻译接口，译文只替换页面显示，不写回会话数据；结果按原文缓存。默认开启，可用 `localStorage.setItem('ag-zh-thought-mt', 'off')` 关闭，`localStorage.removeItem('ag-zh-thought-mt')` 恢复。该功能需要联网，关闭后思考正文保持英文。
- 回归测试：`node scripts/test-localization-rules.js`
## 插件边界（重要）

Antigravity **支持插件**，但插件只能提供技能、规则、MCP、侧边栏 UI 面板，**不能直接改写宿主界面文字**。

因此本仓库采用“插件 + ASAR 安装器”的混合形态：

- `plugin/`：可安装到 `~/.gemini/config/plugins/antigravity-zh-cn`，提供“安装/修复/还原/状态”对话入口和更新播报；
- `installer/`：安装与修复脚本；插件 `runtime/` 内置引擎与词典，负责实际注入。

## 常用命令

```powershell
# 查看状态
pwsh -File .\installer\status.ps1

# 更新后修复
pwsh -File .\installer\repair.ps1

# 还原英文
pwsh -File .\installer\uninstall.ps1

# 仅安装插件外壳
pwsh -File .\installer\install-plugin.ps1
```

## 目录

- `installer/`：安装、状态、还原、插件安装
- `watcher/`：更新检测与自动重装
- `plugin/`：Antigravity 插件外壳（技能、规则、SessionStart 播报）
- `tools/`：ASAR 读取与版本检测
- `dicts/`、`localization_engine.js`：上游汉化词典与注入引擎
- `NOTICE.md`：上游归属与本 Fork 新增说明

---
# Antigravity 中文汉化引擎（Windows / macOS / Linux）

> **支持系统**：Windows / macOS / Linux（含 Ubuntu 等常见发行版）
>
> **语言支持**：简体中文
>
> **汉化版本**：v2.32.1
>
> **匹配版本**：Antigravity v2.32.1
>
> **最近更新**：2026-11-14
>
> **核心运行环境**： Node.js
>
> **汉化范围**：当前 v2.32.1 词典面向 Antigravity v2.32.1，覆盖主界面、顶部系统菜单、标签页与编辑器原生右键菜单、任务栏菜单、加载页、设置面板、新手引导与登录流程、对话及自动化/计划任务管理、个性化定制与插件市场、MCP 服务器商店，以及各类动态状态、提示和操作反馈。少量内容可能因客户端异步渲染、第三方嵌入或官方后续新增界面而暂未覆盖。
>
> **注入原理**：通过 ASAR 还原与重包，安全注入 `preload.js` 动态翻译机制，macOS 端自动完成隔离属性清除与由内而外应用自签名，绝不修改核心二进制，一键安装与完美还原。

> [!IMPORTANT]
> **内容隔离与匹配机制说明（开发者必读）**：
>
> - **全方位内容禁区隔离**：
>   - **会话与思考流隔离**：默认跳过用户消息（`data-testid="user-input-step"`，仅放行 `Commented on:` 等固定 UI 标签）、散文段落及工具活动折叠块（如 `Explored/Edited X files`、`Ran X commands`），状态区仅翻译顶层进度与耗时（如 `工作中`、`正在压缩`、`工作了 XX 分钟`）。模型“思考”正文不再整块跳过，而是标记为 `data-ag-thought-body`，由独立的按需翻译队列处理：只译纯英文段落，跳过代码块、路径与标识符，译文仅存在于页面显示层。
>   - **文件树、路径与代码/图标隔离**：通过 `WeakMap` 缓存与整树剪枝，直接跳过工作区文件树（`role="tree"` / `treeitem`）、辅助面板路径面包屑（`File path breadcrumbs`）、动态文件/目录标签页、变更文件列表路径、Monaco 编辑器、代码预览区与代码块（`.code-line` / `.line-content` / `.code-block` / `data-line-tokens`）、终端及图标字体节点（`.google-symbols` / `.codicon` 等），确保原文件名、目录路径与图标绝不被误译。
>   - **自定义禁区**：任意容器添加 `data-ag-localization-skip` 属性即可显式禁用其子树翻译。
> - **核心匹配与性能机制**：
>   - **1:1 匹配与独立控件守卫**：文本归一化后与词典 1:1 匹配；短词与单字词条受独立控件守卫（`isIsolatedUiControlLabel`）约束，仅在独立按钮、菜单、表头或表单控件上生效；长度 > 20 的具体长句支持带单词边界保护的子串替换。
>   - **零阻塞遍历**：全链路采用有界文本提取（`getBoundedTextContent`），仅作用于受控 UI 渲染节点，绝不改写底层存储或请求数据；界面结构更新时请按 `AGENTS.md` 核对边界。

## 📸 汉化效果展示

以下是部分功能板块的实际汉化效果展示，涵盖登录引导页、主编辑器界面与详细设置面板：

### 1. 欢迎页与登录新手引导

![欢迎页与登录新手引导](./showimg/showlogin.png)

### 2. 主编辑器界面与菜单

![主编辑器界面与菜单](./showimg/showmain.png)

### 3. 详细参数设置面板

![详细参数设置面板](./showimg/showmenu.png)

---

## 📂 项目文件结构

- **`双击安装中文汉化.bat`**：Windows 一键汉化执行入口。
- **`双击卸载还原官方英文.bat`**：Windows 使用备份还原官方英文入口。
- **`双击安装中文汉化.command`**：macOS Finder 双击一键汉化执行入口。
- **`双击卸载还原官方英文.command`**：macOS Finder 双击还原官方英文入口。
- **`install.sh`**：macOS / Linux 一键汉化终端执行入口。
- **`uninstall.sh`**：macOS / Linux 使用备份还原官方英文终端执行入口。
- **`localization_engine.js`**：核心汉化逻辑，跨平台自动适配，负责 app.asar 的解包、代码注入、macOS 隔离修复与自签名及重新打包。
- **`dicts/`**：汉化字典文件夹，内含按模块分类的 JSON 对照翻译字典；当前版本的核心词典为 `dicts/release.json`。
- **`scripts/ag_audit.js`**：只读工程巡检与动态排查脚本，自动完成词典校验、注入脚本沙箱编译验证、桌面壳动态锚点体检与运行态前端文案检索。
- **`.agents/skills/sync-marketplace-plugins/`**：官方插件市场与 MCP 商店联合同步审计技能，内置直连官方云端插件元数据、实时获取官方 MCP 商店条目及内存零落盘解析的全自动比对审计工具。
- **`AGENTS.md`**：项目通用规则。支持 `AGENTS.md` 的 AI 会将其作为项目上下文，按其中的汉化边界与动态文案处理要求工作。
- **`.gitattributes`**：Git 属性规则。它会保护 Windows `.bat` 文件的 GBK/CRLF 字节内容与 macOS `.command` 文件的 LF 换行符，避免 Git 的自动文本转换破坏安装或卸载脚本。

---


## 🚀 使用指南

### 1. 获取汉化包代码（二选一）

* **方法 A：直接下载 ZIP 压缩包（最便捷 📦）**

  1. 点击页面右上角绿色的 **`Code`** 按钮。
  2. 在下拉菜单中选择 **`Download ZIP`** 并下载。
  3. 将下载好的压缩包**解压到您电脑本地的任意目录**（例如您的 `Downloads` 文件夹）。
* **方法 B：通过 Git 命令行克隆（开发者推荐 💻）**

  ```bash
  git clone https://github.com/Silas-02/antigravity-desktop-cn.git
  cd antigravity-desktop-cn
  ```

---

### 2. 一键安装汉化

进入解压或克隆的文件夹，按您的操作系统运行对应脚本（脚本会自动关闭正在运行的软件并注入汉化）：

| 平台 | 安装入口 | 权限与提示 |
| :--- | :--- | :--- |
| **Windows** | 双击运行 **`双击安装中文汉化.bat`** | 仅在权限受限时右键选择“以管理员身份运行” |
| **macOS** | 双击 **`双击安装中文汉化.command`** 或终端运行 `./install.sh` | 仅在权限不足时使用 `sudo`（首次拦截详见 [FAQ 3](#常见问题解答-faq)） |
| **Linux** | 终端运行 **`./install.sh`** | 用户目录免提权；系统目录会自动请求提权或直接加 `sudo` |

* **品牌显示**：运行中可按提示选择左上角品牌显示方式（默认显示英文 `Antigravity` 或不显示）。
* **指定路径**：如自动定位失败，可手动指定路径：`./install.sh --install-dir "/path/to/Antigravity"`。
* 运行完成后，重新启动 Antigravity 即可使用汉化界面。

---

### 3. 一键卸载还原

如需恢复官方原版英文，在当前文件夹运行对应的卸载脚本即可无痕秒级还原：

| 平台 | 卸载入口 | 说明 |
| :--- | :--- | :--- |
| **Windows** | 双击运行 **`双击卸载还原官方英文.bat`** | 权限不足时右键“以管理员身份运行” |
| **macOS** | 双击 **`双击卸载还原官方英文.command`** 或终端运行 `./uninstall.sh` | 支持追加 `--install-dir` 手动路径 |
| **Linux** | 终端运行 **`./uninstall.sh`** | 系统目录直接使用 `sudo ./uninstall.sh` |

---

## 🛠️ 汉化原理说明

本引擎采用 **原生 ASAR 内存极速注入**，深度适配 **Antigravity 2.0+** 的 Electron 架构：

1. **自动释放锁**：脚本运行前会自动探测并安全关闭 Antigravity 进程，防止文件占用锁定。
2. **安全备份**：首次运行时，会在软件目录自动创建原始 `app.asar.bak` 文件，确保随时可无损还原。
3. **原生注入定向修补**：
   - 引擎内置轻量 Chromium Pickle 与 ASAR 归档读写协议，纯 Node.js 原生标准库实现，无需联网，不依赖 `npm` 或 `npx`；
   - 完整继承并保留官方 `--unpack` 属性，杜绝将外部 MCP/二进制依赖塞回 ASAR，包体积始终维持在官方原本的轻量水准。
4. **精确目标注入**：
   - 注入 `preload.js`：采用 WeakMap 记录与 Shadow DOM 穿透，启动高效的 `MutationObserver` 引擎，动态监测并将渲染层文本翻译为中文。
   - 注入 `menu.js`：在确认的插入点补充系统级标题栏与原生菜单（含 macOS 专有菜单）译文。
   - 注入 `tray.js`：汉化托盘与右键通知状态菜单。
   - 注入 `updater.js`：汉化固定的更新检查结果弹窗与原生菜单更新状态项。
   - 注入 `wsl.js` / `provisionSplash.js` / `main.js` / `utils.js` / `subframeLocalizationPreload.js`：汉化 WSL 引导遮罩与错误弹窗，并在 Hub `did-frame-finish-load` 时仅向 `plugin://` 扩展子框架安全注入动态翻译脚本。
   - 注入 `ipcHandlers.js`：汉化原生右键上下文菜单。
5. **macOS 隔离修复与自签名**：还原与注入后，自动递归清除 `com.apple.quarantine` 隔离属性，并采用 Inside-Out 模式对框架与 App 执行 ad-hoc 自签名。

---

## 💡 如何通过 AI 助手自动补充汉化？

若在使用中遇到漏译的文案，直接发送截图或文字描述即可让 AI 助手协助更新词库：

> [!TIP]
> - **推荐做法**：在 Antigravity 中点击 **“打开文件夹”** 将本汉化包目录作为工作区打开后与 AI 对话，AI 会自动读取 `AGENTS.md` 规范并精准定位词典。
> - **免开项目**：若在其他项目工作区中提问，请在提示词中附带汉化包路径，例如：*“我的汉化包在 `~/Downloads/antigravity-desktop-cn`，请先阅读其 `AGENTS.md` 再根据截图补充词典。”*

### 📋 常用提示词（Prompt）模板

<details>
<summary><strong>1. 方式一：直接在聊天中发送截图（推荐 📸）</strong></summary>

如果您不方便打字，可以直接将未汉化干净的界面截图粘贴发送给 AI，并附带以下指令：

> **"请先阅读项目中的 `AGENTS.md`，识别截图中属于 Antigravity 固定界面的漏译文本，并按项目规则补充到词典或引擎中；不要翻译用户内容、路径、命令或诊断正文。"**
> *(AI 应先确认英文来源和界面语境，再选择固定词条或动态规则。)*

</details>

<details>
<summary><strong>2. 方式二：直接在聊天中发送文字描述（极速 ✍️）</strong></summary>

如果您只想修改或增加某一个特定词汇，可以直接发送文字描述给 AI：

> **"帮我把漏译的英文 'Allow agent to view and edit files outside of the current workspace automatically' 汉化为 '允许智能体自动查看并编辑当前工作区之外的文件'。"**
> *(AI 仍应先搜索现有词典并确认该文本是固定界面词条，再决定修改位置。)*

</details>

<details>
<summary><strong>3. 方式三：一键同步与审计官方插件市场与 MCP 商店🧩 </strong></summary>

当 Antigravity 客户端更新版本后，官方插件市场与 MCP 服务器商店可能会新增条目、更新说明文案或下架旧项目。您可以直接向 AI 发送指令进行全自动联合比对审计：

> **"请使用 `sync-marketplace-plugins` 技能比对官方插件市场与 MCP 服务器商店元数据，检查是否有新上架条目、文案变动或已下架项目，并输出比对报告。"**

AI 会自动激活内置技能并调用原生 Node.js 工具，同时以官方权威云端插件数据及运行态客户端 MCP 商店元数据为基准，分别比对 `dicts/marketplace_plugins.json` 与 `dicts/page_mcp_knowledge.json`，并采用流式内存零落盘技术精准提取技能详情，呈现结构化清单后再执行汉化或清理。

</details>


## 常见问题解答 (FAQ)

<details>
<summary><strong>1）提示“未检测到 Node.js 环境”</strong></summary>

* **原因**：汉化引擎基于 Node.js 运行。
* **说明**：引擎为纯原生标准库实现，**仅需系统具备最基础的 `node` 运行时即可**。
* **解决**：安装 Node.js（LTS 版本即可）：
  ```bash
  # Windows
  # 可直接访问 https://nodejs.org 下载安装包，或通过 winget 安装：
  winget install OpenJS.NodeJS.LTS

  # macOS (使用 Homebrew)
  brew install node

  # Ubuntu/Debian
  sudo apt update && sudo apt install -y nodejs

  # 或使用 NodeSource 安装最新 LTS
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
  ```

</details>

<details>
<summary><strong>2）提示"权限不足"或"找不到命令"</strong></summary>

* **解决**：
  - **Windows**：默认普通双击对应 `.bat` 文件；只有出现权限不足时，才右键选择 **“以管理员身份运行”**。
  - **macOS**：直接双击对应 `.command` 或运行 `./install.sh` / `./uninstall.sh`；只有安装在系统目录（如 `/Applications/`）且提示权限不足时，才使用 `sudo ./install.sh` 或 `sudo ./uninstall.sh`。
  - **Linux**：
    - **权限智能自适应**：用户目录安装直接运行 `./install.sh` 或 `./uninstall.sh`，完全无需管理员权限；若目标位于系统目录，脚本会在执行前自动检测并请求 `sudo` 提权，亦可直接以 `sudo ./install.sh` 或 `sudo ./uninstall.sh` 一步运行，无需反复切换执行方式。
    - **脚本执行权限自愈与环境保留**：仓库脚本已默认固化可执行权限（`chmod +x`）；若因解压或环境原因丢失执行位，脚本会在运行时自动修复并固化权限，杜绝因权限不足而必须手动键入 `bash ./install.sh`；同时在提权时会自动保留并向下传递 NVM/FNM 等用户级 Node.js 运行时路径。

</details>

<details>
<summary><strong>3）macOS 双击 .command 提示“Apple无法验证...”或“移到废纸篓”？</strong></summary>

* **原因排查**：
  1. **隔离属性（Quarantine）机制**：通过浏览器从 GitHub 下载 ZIP 压缩包并解压后，macOS 会自动对所有从网络下载的文件添加扩展属性 `com.apple.quarantine`（网络隔离标记）。
  2. **脚本未公证**：`.command` 本质是 Bash Shell 脚本，并非经过 Apple 官方付费开发者证书签名和公证（Notarized）的二进制程序。macOS 安全机制（Gatekeeper）在检测到带有网络隔离标记且没有官方公证凭证的脚本被双击时，会默认拦截并弹出提示：“Apple无法验证‘双击安装中文汉化.command’是否包含可能危害Mac安全或泄漏隐私的恶意软件”，且默认弹窗中只提供“完成”和“移到废纸篓”。
* **解决方案（任选其一即可）**：
  - **方案 1：按住 Control 键右键打开（最简单，推荐 ⭐️）**
    1. 在“访达（Finder）”中，找到 `双击安装中文汉化.command`（或卸载还原脚本）。
    2. 按住键盘上的 **Control** 键不放，点击该文件（或直接鼠标右键点击）。
    3. 在弹出的右键菜单中，点击 **“打开”**。
    4. 此时系统弹出的提示框中，除了“完成”和“废纸篓”，还会多出一个 **“打开”** 按钮。
    5. 点击 **“打开”** 即可正常启动终端执行，系统之后也会记住该操作，不再重复拦截。
  - **方案 2：在系统设置中允许放行**
    1. 打开 macOS 的 **“系统设置”**（System Settings）。
    2. 进入 **“隐私与安全性”**（Privacy & Security），向下滚动找到“安全性”区域。
    3. 找到提示：“已阻止使用‘双击安装中文汉化.command’，因为来自身份不明的开发者”，点击旁边的 **“仍要打开”** 即可。
  - **方案 3：终端一键清除隔离属性并赋予权限（彻底解决）**
    打开 Mac 的“终端（Terminal）”，进入解压后的汉化包文件夹，执行以下命令彻底清除网络隔离标记：
    ```bash
    # 1. 切换到解压目录 (或者直接在终端输入 cd 后，将 Finder 中的该文件夹拖入终端)
    cd /path/to/antigravity-desktop-cn

    # 2. 递归移除当前目录下所有文件的隔离标记
    xattr -d -r com.apple.quarantine .

    # 3. 确保脚本拥有可执行权限
    chmod +x *.command *.sh
    ```
    执行完毕后，即可像预期一样直接双击 `双击安装中文汉化.command` 运行。
  - **方案 4：直接使用终端运行 install.sh（项目官方支持方式）**
    打开终端进入解压目录后，直接在终端中运行：
    ```bash
    ./install.sh
    ```
    （如果提示权限不足，再按照提示使用 `sudo ./install.sh`）。

</details>

<details>
<summary><strong>4）软件官方更新后，汉化失效了怎么办？</strong></summary>

* 软件升级时，官方会覆盖 `app.asar` 文件。重新运行一次安装脚本注入即可（Windows 双击 `双击安装中文汉化.bat`，macOS 双击 `双击安装中文汉化.command` 或运行 `./install.sh`，Linux 运行 `./install.sh`）。

</details>

## 🤝 致谢与项目关系

本项目 Fork 自 [qqxpee/antigravity2-cn](https://github.com/qqxpee/antigravity2-cn)，衷心感谢原作者 **qqxpee** 的开源贡献与开拓性工作！

在此基础上，为了提升汉化长期维护性、系统兼容性与渲染安全边界，本项目进行了深度的工程化重构与迭代，主要特性包括：

1. **跨平台原生支持与脚本体验重构**：
   - 完备支持 Windows、macOS 与 Linux（含Ubuntu等主流发行版），提供开箱即用的一键安装（`install.sh` / `.bat` / `.command`）与无损还原（`uninstall.sh` / `.bat` / `.command`）方案。
   - 引入编码保护（GBK/CRLF 隔离）、macOS 隔离属性修复与由内而外应用自签名、以及权限自适应机制，杜绝 Windows 控制台乱码、macOS 签名失效闪退与 Linux 权限异常。

2. **严格的内容隔离与高安全渲染保护边界**：
   - **用户消息与思考流隔离**：严格适配客户端的 `data-testid="user-input-step"`、`data-ag-localization-skip` 及会话工具活动折叠区禁区机制，坚决不翻译、不篡改用户提示词正文、代码块与终端输出。模型思考正文仅在显示层按需翻译为中文，不写回会话数据；关闭开关后完全保留英文原文，避免误译与数据污染。
   - **分级精准匹配与零阻塞遍历**：结合独立 UI 控件边界守卫（`isIsolatedUiControlLabel`）、带单词边界保护的长句替换规则，以及 `WeakMap` 祖先缓存与 Monaco/代码行整树剪枝，杜绝短词误伤非界面文本并保障大型设置面板与代码预览流畅无卡顿。

3. **原生极速注入架构（零网络依赖与秒级注入）**：
   - **摆脱外部包与网络限制**：彻底摒弃传统依赖 `npx -y @electron/asar` 联网下载并全量解包的方式，内置轻量原生 ASAR 读写协议，100% 离线运行，免装 `npm`。
   - **零临时文件与无感部署**：仅对目标脚本进行内存流式修补，无磁盘小碎文件生成，从根源上消除 Windows Defender 等安全软件的拦截与卡顿。
   - **严格体积守恒**：精准继承官方 `--unpack` 机制，防止将外部二进制及 MCP 工具重复打包进 ASAR，避免体积膨胀。

4. **官方插件市场、MCP 商店与技能体系自动化同步与审计**：
   - **独立分包覆盖**：分别维护 `dicts/marketplace_plugins.json` 与 `dicts/page_mcp_knowledge.json`，全量覆盖 Google 官方专区、合作伙伴专区插件及官方 MCP 服务器商店。
   - **双源联动与内存零落盘比对架构**：默认直连官方云端权威接口实时拉取最新插件清单并在内存中流式提取技能元数据，同时支持与运行态 Antigravity 客户端联动审计官方 MCP 商店条目。
   - **技能选择器安全有界绑定**：在斜杠命令与技能选择器中提供中文友好展示，防止底层路径或技术标识符被意外汉化污染。








