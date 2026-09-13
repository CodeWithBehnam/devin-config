#!/usr/bin/env bash
# install.sh - Install Devin CLI global config (hooks, rules, commands, templates, skills)
#
# Usage: ./install.sh
#
# Copies all files to their correct locations:
#   config.json hooks  -> merged into ~/.config/devin/config.json
#   scripts/*         -> ~/.config/devin/scripts/
#   AGENTS.md         -> ~/.config/devin/AGENTS.md
#   HOOKS.md          -> ~/.config/devin/HOOKS.md
#   templates/*       -> ~/.config/devin/templates/
#   commands/*.md     -> ~/.claude/commands/
#   skills/*          -> ~/.config/devin/skills/
#
# Existing files are backed up with .bak suffix before overwriting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

backup() {
  local dest="$1"
  if [ -f "$dest" ]; then
    cp "$dest" "${dest}${BACKUP_SUFFIX}"
    echo "  backed up: $dest -> ${dest}${BACKUP_SUFFIX}"
  fi
}

echo "=== Installing Devin CLI global config ==="

# 1. Scripts
echo ""
echo "--- Hook scripts -> ~/.config/devin/scripts/ ---"
mkdir -p ~/.config/devin/scripts
for script in "$SCRIPT_DIR"/scripts/*.sh "$SCRIPT_DIR"/scripts/*.py; do
  [ -f "$script" ] || continue
  dest=~/.config/devin/scripts/"$(basename "$script")"
  backup "$dest"
  cp "$script" "$dest"
  chmod +x "$dest"
  echo "  installed: $dest"
done

# 2. AGENTS.md (user-level rules)
echo ""
echo "--- AGENTS.md -> ~/.config/devin/AGENTS.md ---"
backup ~/.config/devin/AGENTS.md
cp "$SCRIPT_DIR/AGENTS.md" ~/.config/devin/AGENTS.md
echo "  installed: ~/.config/devin/AGENTS.md"

# 3. HOOKS.md (documentation)
echo ""
echo "--- HOOKS.md -> ~/.config/devin/HOOKS.md ---"
if [ -f "$SCRIPT_DIR/HOOKS.md" ]; then
  backup ~/.config/devin/HOOKS.md
  cp "$SCRIPT_DIR/HOOKS.md" ~/.config/devin/HOOKS.md
  echo "  installed: ~/.config/devin/HOOKS.md"
fi

# 4. Templates
echo ""
echo "--- Templates -> ~/.config/devin/templates/ ---"
mkdir -p ~/.config/devin/templates
cp -r "$SCRIPT_DIR"/templates/* ~/.config/devin/templates/
echo "  installed: ~/.config/devin/templates/"

# 5. Slash commands
echo ""
echo "--- Slash commands -> ~/.claude/commands/ ---"
mkdir -p ~/.claude/commands
for cmd in "$SCRIPT_DIR"/commands/*.md; do
  [ -f "$cmd" ] || continue
  dest=~/.claude/commands/"$(basename "$cmd")"
  backup "$dest"
  cp "$cmd" "$dest"
  echo "  installed: $dest"
done

# 6. Skills
echo ""
echo "--- Skills -> ~/.config/devin/skills/ ---"
mkdir -p ~/.config/devin/skills
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dest=~/.config/devin/skills/"$skill_name"
  mkdir -p "$dest"
  cp -r "$skill_dir"* "$dest/"
  echo "  installed: $dest"
done

# 7. Merge hooks into config.json
echo ""
echo "--- Merging hooks into ~/.config/devin/config.json ---"
CONFIG=~/.config/devin/config.json
if [ ! -f "$CONFIG" ]; then
  echo '{}' > "$CONFIG"
fi
backup "$CONFIG"

/usr/bin/python3 -c "
import json, sys

with open('$SCRIPT_DIR/config.json') as f:
    new = json.load(f)

with open('$CONFIG') as f:
    existing = json.load(f)

existing['hooks'] = new.get('hooks', {})

with open('$CONFIG', 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')

print('  merged hooks into', '$CONFIG')
"

# 8. Create logs directory
mkdir -p ~/.config/devin/logs
echo "  created: ~/.config/devin/logs/"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Verify in a Devin session with: /hooks"
echo "Restart Devin for all changes to take effect."
