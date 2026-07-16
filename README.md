# codex-dotfiles

个人 Codex 使用习惯同步仓库：`AGENTS.md`、安全版 `config.toml`、用户 skills 快照、官方/system/plugin skills 清单。

## 一键同步

Windows:

```powershell
git clone https://github.com/SunS1eep1ng/codex-dotfiles.git codex-dotfiles
cd codex-dotfiles
powershell -ExecutionPolicy Bypass -File .\scripts\sync-codex.ps1
```

Linux / macOS / server:

```bash
git clone https://github.com/SunS1eep1ng/codex-dotfiles.git codex-dotfiles
cd codex-dotfiles
bash scripts/sync-codex.sh
```

同步内容：

- `AGENTS.md` -> `$CODEX_HOME/AGENTS.md`
- 用户拥有的 `skills/` -> `$CODEX_HOME/skills/`
- `config/config.toml.template` 中的便携偏好 -> `$CODEX_HOME/config.toml`

脚本会先备份发生变化的 `AGENTS.md` 和 `config.toml`。Linux/macOS 默认安全合并配置，保留 MCP、密钥和机器路径；设置 `CONFIG_MODE=replace` 才会整份替换。skills 默认只覆盖同名文件，不删除目标机器额外的 skill；需要严格镜像用户 skills 时，Windows 用 `-MirrorSkills`，该模式仍会保留 `.system`。

## 更新这个仓库

在主力机器上改完 Codex 习惯后：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-current.ps1
git status
git add .
git commit -m "chore: update codex dotfiles"
```

然后手动 push 到你的远程仓库。

导出脚本会：

- 检查本机 skills 的中英文触发词。
- 只提取安全、可跨机器复用的 config 和 plugin 启用状态。
- 忽略 `.env`、private key、SQLite、`__pycache__` 等本机或敏感文件。
- 不复制与 Codex 版本绑定的 `.system` 和 plugin cache，只记录其清单。
- 生成稳定的 skill/plugin 清单，并执行公开仓库安全检查。

## 每日 Automation

每日同步使用的完整 prompt 位于 `docs/daily-automation-prompt.md`。计划时间为每天 `18:00 Asia/Shanghai`，仅在本机内容确有变化并成功推送 GitHub 后，才非破坏性同步 `yis-imac` 和 `8-4090`。

## 不同步什么

不要把下面这些放进 Git：

- `auth.json`
- `sessions/`、`archived_sessions/`
- `cache/`、`.tmp/`
- `logs_*.sqlite`、`state_*.sqlite`、`memories_*.sqlite`
- MCP token、HTTP header key、浏览器/桌面 runtime 绝对路径

原因：这些是隐私、凭据或机器状态，跨设备复制容易失效或泄露。

## 文档

- `docs/installed-skills.md`: 当前仓库内 skills 清单。
- `docs/official-plugin-skills.md`: 当前机器 plugin cache 中发现的官方/plugin skills 清单。
- `docs/sync-notes.md`: 哪些配置被保留、哪些被刻意排除。
- `docs/daily-automation-prompt.md`: 每日审计、GitHub 更新、远端同步与汇报规则。
