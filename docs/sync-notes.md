# Sync Notes

## 保留

- `AGENTS.md`: 个人长期使用习惯。
- `skills/`: 当前机器 `$CODEX_HOME/skills` 的完整快照。
- `config/config.toml.template`: 可跨机器复用的 Codex 偏好、插件启用状态、基础 provider 设置。

## 排除

- `auth.json`: 登录凭据。
- `sessions/`、`archived_sessions/`: 对话内容和工作历史。
- `cache/`、`.tmp/`、`plugins/cache`: 机器生成缓存。
- `logs_*.sqlite`、`state_*.sqlite`、`memories_*.sqlite`: 本机状态数据库。
- `mcp_servers.*.http_headers` 中的真实 token/key。
- `notify`、`node_repl`、`marketplaces.*.source` 等绝对路径。
- `[projects]` trusted path 列表。

## 原因

这些内容要么包含隐私/凭据，要么绑定单台机器路径。同步它们会增加泄露风险，也容易导致另一台机器 Codex 启动后找不到 runtime 或误信任错误路径。
