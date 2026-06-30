#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SKIP_CONFIG="${SKIP_CONFIG:-0}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  local path="$1"
  if [ -f "$path" ]; then
    cp -p "$path" "$path.bak-$TIMESTAMP"
  fi
}

mkdir -p "$CODEX_HOME" "$CODEX_HOME/skills"

backup_file "$CODEX_HOME/AGENTS.md"
cp "$REPO_ROOT/AGENTS.md" "$CODEX_HOME/AGENTS.md"

if [ "$SKIP_CONFIG" != "1" ]; then
  backup_file "$CODEX_HOME/config.toml"
  cp "$REPO_ROOT/config/config.toml.template" "$CODEX_HOME/config.toml"
fi

for entry in "$REPO_ROOT"/skills/* "$REPO_ROOT"/skills/.[!.]* "$REPO_ROOT"/skills/..?*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  cp -a "$entry" "$CODEX_HOME/skills/$name"
done

echo "Synced Codex dotfiles to $CODEX_HOME"
echo "Backups use suffix .bak-$TIMESTAMP"
if [ "$SKIP_CONFIG" != "1" ]; then
  echo "Review local MCP secrets after config sync; real keys are intentionally not stored in this repo."
fi
