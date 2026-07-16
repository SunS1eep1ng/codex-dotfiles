#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SKIP_CONFIG="${SKIP_CONFIG:-0}"
CONFIG_MODE="${CONFIG_MODE:-merge}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  local path="$1"
  if [ -f "$path" ]; then
    cp -p "$path" "$path.bak-$TIMESTAMP"
  fi
}

mkdir -p "$CODEX_HOME" "$CODEX_HOME/skills"

if ! cmp -s "$REPO_ROOT/AGENTS.md" "$CODEX_HOME/AGENTS.md" 2>/dev/null; then
  backup_file "$CODEX_HOME/AGENTS.md"
  cp "$REPO_ROOT/AGENTS.md" "$CODEX_HOME/AGENTS.md"
  echo "Updated AGENTS.md"
else
  echo "AGENTS.md unchanged"
fi

if [ "$SKIP_CONFIG" = "1" ]; then
  CONFIG_MODE="skip"
fi

case "$CONFIG_MODE" in
  skip)
    echo "Skipped config.toml"
    ;;
  replace)
    if ! cmp -s "$REPO_ROOT/config/config.toml.template" "$CODEX_HOME/config.toml" 2>/dev/null; then
      backup_file "$CODEX_HOME/config.toml"
      cp "$REPO_ROOT/config/config.toml.template" "$CODEX_HOME/config.toml"
      echo "Replaced config.toml"
    else
      echo "config.toml unchanged"
    fi
    ;;
  merge)
    if [ -f "$CODEX_HOME/config.toml" ]; then
      if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required for safe config merge; use CONFIG_MODE=skip or replace" >&2
        exit 1
      fi
      python3 "$SCRIPT_DIR/merge-portable-config.py" \
        "$REPO_ROOT/config/config.toml.template" \
        "$CODEX_HOME/config.toml" \
        --backup-suffix ".bak-$TIMESTAMP"
    else
      cp "$REPO_ROOT/config/config.toml.template" "$CODEX_HOME/config.toml"
      echo "Created config.toml from portable template"
    fi
    ;;
  *)
    echo "Invalid CONFIG_MODE: $CONFIG_MODE (expected merge, replace, or skip)" >&2
    exit 1
    ;;
esac

copied_skills=0
for entry in "$REPO_ROOT"/skills/* "$REPO_ROOT"/skills/.[!.]* "$REPO_ROOT"/skills/..?*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  destination="$CODEX_HOME/skills/$name"
  if [ -d "$entry" ]; then
    mkdir -p "$destination"
    cp -a "$entry"/. "$destination"/
  else
    cp -p "$entry" "$destination"
  fi
  copied_skills=$((copied_skills + 1))
done

echo "Synced Codex dotfiles to $CODEX_HOME"
echo "Updated $copied_skills shared skill entries; remote-only skills were preserved"
echo "Changed AGENTS.md/config.toml files are backed up with suffix .bak-$TIMESTAMP"
