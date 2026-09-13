#!/usr/bin/env bash
# block-writes-outside.sh — PreToolUse hook for Devin CLI
#
# Blocks write/edit/apply_patch/notebook_edit from modifying files OUTSIDE the
# project directory. Prevents the agent from touching ~/.zshrc, system configs,
# its own hook scripts, or any other location outside the repo.
#
# Allowed locations:
#   - Inside DEVIN_PROJECT_DIR (the repo)
#   - /tmp (scratch space for temp files)
#
# Blocked: everything else, including ~/.config/devin/ (the hooks themselves).

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

case "$tool_name" in
  write|edit|apply_patch|notebook_edit) ;;
  *) exit 0 ;;
esac

file_path="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("file_path","")
    print(v if isinstance(v,str) else "")
except Exception: print("")
')"

[ -z "$file_path" ] && exit 0

# Expand ~ to $HOME.
fp="${file_path/#\~/$HOME}"

# Resolve to absolute (handle relative paths relative to project dir).
proj="${DEVIN_PROJECT_DIR:-}"
case "$fp" in
  /*) ;;  # already absolute
  *)
    if [ -n "$proj" ]; then
      fp="$proj/$fp"
    fi
    ;;
esac

# Normalize (collapse . and ..).
fp_norm="$(cd "$fp" 2>/dev/null && pwd -P || printf '%s' "$fp")"

block() {
  printf '%s' '{"decision":"block","reason":"Write outside project dir blocked by global Devin hook: '"$1"'"}'
  exit 2
}

# Allow /tmp (scratch).
case "$fp_norm" in
  /tmp/*|/tmp) exit 0 ;;
esac

# Allow inside project dir.
if [ -n "$proj" ]; then
  proj_norm="$(cd "$proj" 2>/dev/null && pwd -P || printf '%s' "$proj")"
  case "$fp_norm" in
    "$proj_norm"|"$proj_norm"/*) exit 0 ;;
  esac
fi

# Everything else is blocked.
block "$file_path"
