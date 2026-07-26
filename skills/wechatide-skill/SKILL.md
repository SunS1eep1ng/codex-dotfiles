---
name: wechatide-skill
description: >-
  微信开发者工具任务根入口。先完成环境与登录检查，再路由到创建项目、初始化、项目管理、项目配置、
  编译、预览、页面自动化、调试或云开发操作。适用于小程序与小游戏。用户提到微信开发者工具、
  小程序/小游戏模拟器、新建项目、预览上传、自动化点击、console/network、云函数/云数据库时使用。
  Use for WeChat DevTools tasks involving mini-program or mini-game setup, compilation, preview,
  UI automation, debugging, or CloudBase operations.
metadata:
  short-description: 微信开发者工具 skill 包
---

# wechatide-skill

## 用途

面向微信开发者工具工作流的根入口。**小程序与小游戏同等适用**（除非某工具参数或说明明确限定类型）。

**应使用**：小程序/小游戏项目的页面自动化与验证；运行时/截图/日志排查；云环境与云函数；编译、预览、上传、登录；项目管理与 `project.config.json` 配置。

**不应使用**：通用编码辅助；与小程序/小游戏无关的桌面自动化；任意 shell / 未注册工具调用。

## Skill 安装与同步

内置目录与版本以 `check_wechatide_status` 返回的 `skillPath` / `skillVersion` 为准，不要猜路径或硬编码版本号。

### 同步步骤（首次安装与 `agent_behind` 共用）

1. 确认 CLI：`wechatide -h`（`command not found` 则先装 CLI / 配 PATH）
2. 查状态拿到路径（**必须**带 `--skill-version`）：
   - 已加载本 skill：传当前 `skill.yaml` 的 `version`
   - 尚未导入：可临时传 `0.0.0`，仅用于取出 `skillPath`
3. 在当前 agent 里用返回的 **`skillPath` 绝对路径** 导入或**覆盖**已有 `wechatide-skill`（整目录对齐内置内容；**不要**只改 `version` 字段）
4. **重新加载 skill** 或**新开会话**（多数产品不热更新已加载的 skill 正文）
5. 再读新 `skill.yaml` 的 `version`，执行下方「运行前检查」，直到 `versionRelation: equal`

`agent_ahead`：先提示用户**更新微信开发者工具**；若暂不能升级，也可按上述同步步骤用 `skillPath` 与当前内置对齐，然后重查。

## 运行前检查（必须）

进入任何 scene 或调用工具前，确认环境就绪、用户已登录（游客不可继续），且 skill 版本已对齐。

### 1. 检查状态

```bash
wechatide -c <clientName> check_wechatide_status --skill-version <skillVersionFromSkillYaml> [--token <cliAccessToken>]
```

`<skillVersionFromSkillYaml>`：当前 agent 已加载的 `wechatide-skill/skill.yaml` 顶层 `version`。**会话首次检查必须传**；不传则跳过对比并返回 `warning`，**不得当作就绪**。

若 MCP 未启动或 client 未授权，CLI 会用同一 `<clientName>` 自动 `auth` 一次；授权弹窗仍需用户确认。未开启访问令牌校验时，授权后会自动重试；已开启时，auth 只返回 `tokenRequired: true`，不会返回访问令牌，须让用户提供安全设置中配置的访问令牌并通过 `--token` 重新执行。

| 返回 | 处理 |
|------|------|
| `loginExpired: false` 且 `versionRelation: equal` | 就绪，继续 |
| `versionRelation: skip_check` / 有「未传入 agent skill 版本」类 `warning` / `versionRelation` 非 `equal` | 补传 `--skill-version` 或按 `versionRelation` 同步后重查，不得继续业务工具 |
| `command not found` | CLI 未安装或不在 PATH |
| `CONNECT_ERROR` / `AUTH_*` | 自动授权失败；必要时手动 `wechatide auth -c <clientName>` |
| `loginExpired: true` | 扫码登录：`wechatide -c <clientName> login`，完成后再查状态 |
| `versionRelation: agent_behind` | 按上文「同步步骤」用 `skillPath` 覆盖导入 → 重载 skill → 用新 `version` 重查 |
| `versionRelation: agent_ahead` | 提示更新微信开发者工具，或同步 `skillPath` 后重查 |

成功对比时还会返回：

- `loginExpired`: `true` \| `false`（**是否已登录以此为准**；`false` 时通常另有 `loginUser`）
- `versionRelation`: `equal` \| `agent_behind` \| `agent_ahead` \| `skip_check`（**版本是否对齐以此为准**；未传 `--skill-version` 时为 `skip_check`）
- 不一致或未传版本时另有 `warning`；对比场景下还有 `skillVersion` / `skillPath`

**会话开始调用一次即可**；确认 `loginExpired: false` 且 `versionRelation: equal`（无版本相关 `warning`）后不要重复调用。

需要手动重试时执行：

```bash
wechatide auth -c <clientName>
```

服务端口关闭时，授权弹窗会提示用户，点击允许后同时开启服务端口。若已配置访问令牌，auth 只告知需要 Token，不返回令牌内容。

未确认登录、或版本未对齐（含未传 `--skill-version`）前，不得执行其他工具。

## 调用方式

```bash
wechatide -c <clientName> <toolName> [flags...] [--token <cliAccessToken>]
```

- `-c` / `<clientName>`：当前 agent 产品简称（如 `Cursor`、`Claude`、`CodeBuddy`），须与授权弹窗里的 client 一致；同一会话内保持不变
- `<toolName>`：工具名位置参数（下划线，勿用点号/驼峰）
- `--token`：安全设置中配置的 CLI 访问令牌；启用校验后每条 `wechatide` 工具命令都必须携带，未启用时可省略。不得从工具本地数据中读取，也不得写入项目文件或输出到日志
- `--skill-version`：**仅**用于 `check_wechatide_status` 做版本对齐；**不要**传给 `auto_preview` 等业务工具
- 本地路径传绝对路径；`object`/`array` 可用 JSON 或 `--<field>-file`
- **不要编造工具名或参数结构**；先查 [references/tool-index.md](references/tool-index.md)

clientName 授权与 CLI 访问令牌是两层独立校验；clientName 已授权不代表后续命令可以省略已启用的访问令牌。

- **对工具名把握不高，或不确定参数/用法时**：先查帮助，再调用（勿猜 flag）：

```bash
wechatide <toolName> -h
# 等价
wechatide <toolName> --help
```

- 共享工具以 tool-index **主归属**为准（见下表）；次要 scene 仅可按本 scene 文档调用，勿跨 scene 随便混用

### 共享工具主归属

| 工具 | 主归属 | 说明 |
|------|--------|------|
| `automation_runtime_info` | initializer | automator / debugger 可只读取上下文，勿当「开窗」替代 |
| `automation_wx_api` | debugger | 自动化流程内 mock/调用可在 automator |
| `simulator_screenshot` | debugger | 诊断取证（含 StatusBar / Toast） |
| `automation_viewport_action`（`screenshot`） | automator | 写入自动化脚本的截图；勿与 `simulator_screenshot` 混用 |
| `simulator_refresh` / `build_npm` | compiler | debugger 可借用刷新，勿无差别反复刷 |

完整主归属以 [tool-index](references/tool-index.md) 的 scene 列为准（多 scene 时第一项为主）。

## 路由（确认环境就绪后）

| 用户意图 | Scene |
|----------|--------|
| 从零创建小程序/小游戏项目（目录 + 配置 + 导入列表；**非**独立 scene） | `wechatide-tools/references/create-project-guide.md` |
| 打开/关闭项目窗口、登录、AppID、运行时上下文 | `skills/initializer/SKILL.md` |
| 项目列表查询 / 导入 / 从列表删除（不开窗口） | `skills/project-manager/SKILL.md` |
| 改 `project.config.json`（修改基础库版本、域名校验、热重载、编译开关等，不调 MCP） | `skills/project-config/SKILL.md` |
| 编译页面、单文件编译、构建 npm、刷新模拟器 | `skills/compiler/SKILL.md` |
| 预览、二维码、上传体验版（预览优先 `auto_preview`；可不打开窗口） | `skills/previewer/SKILL.md` |
| 点击、输入、滚动、页面断言、自动化脚本 | `skills/automator/SKILL.md` |
| console / network / 截图取证 / 状态诊断 | `skills/debugger/SKILL.md` |
| 云环境、云函数、云数据库、云存储 | `skills/cloudbase-operator/SKILL.md` |
| 小程序地图组件 / 腾讯位置服务 API | `references/map-skill-index.md`（外部 skill） |

选择原则：按**当前主目标**进一个 scene；不要跨 scene 混用原子工具。多目标时先完成 blocker，再移交。

## 跨 scene 移交（必须）

切换 scene / 走完 create-project 后，带上下列上下文（可写入回复，勿丢）：

| 字段 | 要求 |
|------|------|
| `nextScene` | 目标 scene 名，或 `create-project-guide` / 结束 |
| `project` | 已有项目时必填：本地绝对路径 |
| `confirmed` | 已确认事实（如已登录且 `versionRelation: equal`、窗口已开、appid、env、当前页） |
| `blocker` | 未决项；无则省略 |
| 附加 | 见目标 scene「移交」表（页面、选择器、env 等） |

下一 scene：**不要**重复 `check_wechatide_status`；**不要**无故 `open_project_window`（除非 `confirmed` 表明窗口未开且目标需要窗口）。

## 标准工作流

1. 确认 `wechatide` 可用 → `check_wechatide_status --skill-version <skill.yaml 的 version>`（须 `loginExpired: false` + `versionRelation: equal`）
2. 识别项目与目标：
   - 从零创建项目 → `create-project-guide.md`（配置走 project-config，导入用 `project_import`）
   - 仅管理项目列表 → `project-manager`（不开窗口）
   - 预览 / 上传 → `previewer`（**可不打开项目窗口**）
   - 编译 / 调试 / 自动化 → `initializer` 打开窗口后再进对应 scene
3. 选 scene → `wechatide` 调工具 → 按「移交」进入下一步或结束

## 交互与失败

出现授权/扫码/确认弹窗：停在当前步，说明等待内容，用户完成后再继续。详见 [references/approval-policy.md](references/approval-policy.md)。

执行失败：原样抛出错误，不要吞掉或猜测修复。`PROJECT_PATH_NOT_FOUND` / `PROJECT_CONFIG_JSON_ERROR` / `APPID_ERROR` 的后置处理见 [project-tool-error-guide.md](wechatide-tools/references/project-tool-error-guide.md)（勿改成调用前预检）。各 scene「失败快表」只补充本场景特有处理。

## 参考

- 工具索引（含主归属）：[references/tool-index.md](references/tool-index.md)
- 工具注册表：`wechatide-tools/references/tools.yaml`（按需读单工具，勿整文件灌入）
- `--project` 配置/appid 错误：`wechatide-tools/references/project-tool-error-guide.md`
- 创建项目：`wechatide-tools/references/create-project-guide.md`
- 地图外部 skill：`references/map-skill-index.md`
