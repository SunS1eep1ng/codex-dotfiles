# Sync Notes

## 保留

- `AGENTS.md`: 个人长期使用习惯。
- `skills/`: 当前机器 `$CODEX_HOME/skills` 中用户拥有、可跨设备同步的 skills。
- `config/config.toml.template`: 自动提取的可跨机器复用 Codex 偏好、插件启用状态、基础 provider 设置。

## 排除

- `auth.json`: 登录凭据。
- `sessions/`、`archived_sessions/`: 对话内容和工作历史。
- `cache/`、`.tmp/`、`plugins/cache`: 机器生成缓存。
- `skills/.system`: 与当前 Codex 版本绑定；仅在 `docs/official-plugin-skills.md` 记录清单。
- `logs_*.sqlite`、`state_*.sqlite`、`memories_*.sqlite`: 本机状态数据库。
- `mcp_servers.*.http_headers` 中的真实 token/key。
- `notify`、`node_repl`、`marketplaces.*.source` 等绝对路径。
- `[projects]` trusted path 列表。

## 原因

这些内容要么包含隐私/凭据，要么绑定单台机器路径。同步它们会增加泄露风险，也容易导致另一台机器 Codex 启动后找不到 runtime 或误信任错误路径。

## 自动同步规则

- 本机 `$CODEX_HOME` 是共享习惯的上游。
- skill 触发词只修改用户拥有的 skill；`.system` 和 plugin cache 只做清单，不复制或自动翻译。
- GitHub 有真实内容变化时才提交和推送。
- 远端采用非破坏同步：更新仓库已有的同名 skill，保留远端独有 skill。
- Linux/macOS 使用 config merge，仅更新便携键值，保留 MCP、token、绝对路径和其他机器专属段落。
