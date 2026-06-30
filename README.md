# codex-dotfiles

私人 Codex 使用习惯同步仓库：`AGENTS.md`、安全版 `config.toml`、本机 skills 快照、官方/plugin skills 清单。

## 一键同步

Windows:

```powershell
git clone <your-private-repo-url> codex-dotfiles
cd codex-dotfiles
powershell -ExecutionPolicy Bypass -File .\scripts\sync-codex.ps1
```

Linux / macOS / server:

```bash
git clone <your-private-repo-url> codex-dotfiles
cd codex-dotfiles
bash scripts/sync-codex.sh
```

同步内容：

- `AGENTS.md` -> `$CODEX_HOME/AGENTS.md`
- `skills/` -> `$CODEX_HOME/skills/`
- `config/config.toml.template` -> `$CODEX_HOME/config.toml`

脚本会先备份已有 `AGENTS.md` 和 `config.toml`。skills 默认只覆盖同名文件，不删除目标机器额外的 skill；需要严格镜像时，Windows 用 `-MirrorSkills`。

## 更新这个仓库

在主力机器上改完 Codex 习惯后：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-current.ps1
git status
git add .
git commit -m "chore: update codex dotfiles"
```

然后手动 push 到你的私有远程仓库。

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
