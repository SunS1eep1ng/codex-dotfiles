# Daily Codex Dotfiles Automation Prompt

Run this workflow once per scheduled run. The local Windows `$CODEX_HOME` is the upstream source for shared Codex habits. The public `codex-dotfiles` repository is the distribution channel.

Use `$planning-with-files` for progress tracking and `$verification-loop` before publishing.

## Safety

- Work only in the `codex-dotfiles` checkout and `$CODEX_HOME`.
- Never copy or commit credentials, `auth.json`, session data, memories, SQLite files, logs, `.env`, private keys, caches, or machine-specific runtime paths.
- Never reset, rebase, force-push, delete Git history, or overwrite a dirty checkout.
- Never delete remote-only skills. Remote sync is non-destructive.
- If the local repo is dirty before this run, report the paths and stop without committing, pushing, or syncing remotes.
- If a command fails, stop the dependent steps and report the exact host/stage that failed.

## Workflow

1. Confirm the checkout is on `main`, clean, and attached to `SunS1eep1ng/codex-dotfiles`. Run `git fetch origin` and `git pull --ff-only`.
2. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\check-bilingual-skill-triggers.ps1
   ```

3. For every reported user-owned skill, edit only its local `$CODEX_HOME/skills/**/SKILL.md` frontmatter `description`:
   - Preserve the stable skill name and existing English trigger wording.
   - Add concise Chinese trigger phrases that match how a Chinese-speaking user would ask for the skill.
   - If English wording is missing, add concise English trigger wording too.
   - Do not edit `.system` or plugin-cache skills.
4. Run the bilingual checker again. Continue only when it reports no missing bilingual descriptions.
5. Export the current safe state:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\export-current.ps1
   ```

   This exports `AGENTS.md`, filtered user-owned skills, portable config/plugin preferences, and deterministic system/plugin indexes. It does not copy `.system` or plugin caches.
6. Inspect `git status --short` and the complete diff. Ignore no unexpected file. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\check-public-safety.ps1
   git diff --check
   ```

7. If there is no meaningful diff, do not commit or contact the remote hosts. Report `No changes`.
8. If there is a valid diff, stage only `AGENTS.md`, `config/`, `skills/`, and generated files under `docs/`. Review the staged diff and rerun the safety check.
9. Commit as `chore: sync codex dotfiles YYYY-MM-DD`, then push `main` with a normal non-force push. If push fails, do not sync either remote.
10. After a successful push, update each host independently:

    - `yis-imac`: use `~/codex-dotfiles`; clone the public repo there if absent.
    - `8-4090`: use `~/codex-dotfiles`; reuse the existing checkout.
    - Before pulling, require a clean remote checkout. If dirty, skip that host and report it.
    - Capture the remote-only top-level skill directory names before syncing so their preservation can be verified afterward.
    - Run `git fetch origin`, `git checkout main`, and `git pull --ff-only`.
    - Run `CONFIG_MODE=merge bash scripts/sync-codex.sh`.
    - Verify the remote checkout commit equals GitHub/local `main`, `AGENTS.md` matches the repo, every repo skill directory exists remotely, and remote-only skills remain present.

## Daily Report

Always report one result:

- `No changes`: checks performed and no write operations.
- `Updated`: bilingual descriptions changed, exported files changed, commit hash, pushed paths, and per-host sync/verification.
- `Blocked`: failed stage, exact reason, and which later actions were skipped.

Do not include secret values or full private configuration in the report.
