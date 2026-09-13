#!/usr/bin/env bash
# block-dangerous.sh — PreToolUse hook for Devin CLI
#
# Blocks dangerous / destructive shell commands before they run. Covers:
#   - Destructive git: push --force (not --force-with-lease), reset --hard,
#     clean -f*, branch -D, checkout . / restore ., filter-branch, reflog expire
#   - Destructive filesystem: rm -rf on /, ~, $HOME, /*, ., .., or any path
#     outside the project dir; chmod/chown -R on system dirs; dd to disk devs;
#     mkfs/fdisk/diskutil eraseDisk; fork bombs
#   - System: sudo (any), shutdown/reboot/halt/poweroff, kill -9 on PID 1,
#     launchctl bootout, writes to /etc /System /usr /bin /sbin
#   - Remote execution: curl/wget piped into sh/bash/zsh/fish/python
#   - Database: DROP TABLE/DATABASE, TRUNCATE, redis FLUSHALL/FLUSHDB,
#     mongo dropDatabase
#
# Reads the PreToolUse event JSON on stdin. Exits 2 to block (per Devin hook
# spec), printing a JSON decision/reason on stdout so the agent sees why.

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_name",""))
except Exception:
    print("")
')"

# Only the exec tool runs shell commands.
[ "$tool_name" = "exec" ] || exit 0

cmd="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("command","")
    print(v if isinstance(v,str) else json.dumps(v))
except Exception:
    print("")
')"

[ -z "$cmd" ] && exit 0

# Expand ~ so ~/.ssh etc. match.
cmd_exp="${cmd//\~/$HOME}"

block() {
  printf '%s' '{"decision":"block","reason":"Dangerous command blocked by global Devin hook (block-dangerous.sh): '"$1"'"}'
  exit 2
}

# --- Destructive git ---------------------------------------------------------
if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*push.*(--force|-f)([[:space:]]|$)'; then
  # Allow --force-with-lease / --force-with-lease=* (safer).
  if ! printf '%s' "$cmd" | grep -Eq 'force-with-lease'; then
    block "git push --force (use --force-with-lease instead)"
  fi
fi
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*reset[[:space:]].*--hard' && block "git reset --hard"
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*clean[[:space:]].*-([a-zA-Z]*f|fd|fx)' && block "git clean -f"
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*branch[[:space:]].*-D[[:space:]]' && block "git branch -D (force delete)"
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]]+(checkout|restore)[[:space:]]+\.' && block "git checkout . / restore . (discards uncommitted work)"
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*filter-branch' && block "git filter-branch (rewrites history)"
printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])git[[:space:]].*reflog[[:space:]].*expire.*--all' && block "git reflog expire --all"

# --- Destructive filesystem --------------------------------------------------
# rm -rf targeting root, home, glob-root, cwd, parent. Match the LAST token
# only, so "/Users/foo" is not mistaken for "/".
if printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])rm[[:space:]]+[^|]*-rf?[^|]*|--force'; then
  # Extract the last whitespace-delimited token of the rm command (before any pipe).
  rm_part="$(printf '%s' "$cmd_exp" | sed -E 's/.*\brm[[:space:]]+([^|]*)$/\1/; s/[[:space:]]+$//')"
  last_token="$(printf '%s' "$rm_part" | awk '{print $NF}')"
  case "$last_token" in
    /|'/*'|'~'|'$HOME'|'~/*'|'$HOME/*'|'.'|'..') block "rm -rf on dangerous target ($last_token)" ;;
  esac
  # Any rm -rf on an absolute path outside the project dir (skip relative paths).
  if [ -n "${DEVIN_PROJECT_DIR:-}" ]; then
    # Pull out absolute path tokens (start with / or ~).
    outside="$(printf '%s' "$rm_part" | grep -oE '(^|[[:space:]])(/|~/)[A-Za-z0-9_./-]+' | sed -E 's/^[[:space:]]+//' || true)"
    for p in $outside; do
      case "$p" in
        "$DEVIN_PROJECT_DIR"*) ;;  # inside project, allow
        "$DEVIN_PROJECT_DIR"/*) ;; # inside project subdir, allow
        *) block "rm -rf on path outside project dir: $p" ;;
      esac
    done
  fi
fi

# chmod/chown -R on system directories.
printf '%s' "$cmd_exp" | grep -Eq '(chmod|chown)[[:space:]]+[^|;]*-R[^|;]*(/(etc|System|usr|bin|sbin|var|root|home|Users)|~|\$HOME)' && block "recursive chmod/chown on system dir"

# dd writing to a disk device.
printf '%s' "$cmd_exp" | grep -Eq 'dd[[:space:]]+[^|]*of=/dev/(disk|rdisk|sd|hd|nvme|mmcblk)' && block "dd to disk device"

# Filesystem formatting / partitioning.
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])(mkfs|fdisk|diskutil[[:space:]]+eraseDisk)' && block "filesystem format/erase"

# Fork bomb.
printf '%s' "$cmd_exp" | grep -Eq ':\(\)\s*\{\s*:\|.*\}\s*;\s*:' && block "fork bomb"

# --- System ------------------------------------------------------------------
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]|&;])sudo([[:space:]]|$)' && block "sudo (ask the user to run privileged ops)"
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])(shutdown|reboot|halt|poweroff)([[:space:]]|$)' && block "shutdown/reboot"
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])kill[[:space:]]+-9[[:space:]]+1([[:space:]]|$)' && block "kill -9 PID 1"
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])launchctl[[:space:]]+bootout' && block "launchctl bootout"

# Writes (redirection or tee) into system directories.
printf '%s' "$cmd_exp" | grep -Eq '>[[:space:]]*(/etc|/System|/usr|/bin|/sbin)/' && block "write to system directory"
printf '%s' "$cmd_exp" | grep -Eq '(^|[[:space:]])(tee|cp|mv)[[:space:]]+[^|;]*(/etc|/System|/usr|/bin|/sbin)/' && block "copy/move into system directory"

# --- Remote execution --------------------------------------------------------
# curl/wget piped into a shell or python interpreter.
if printf '%s' "$cmd_exp" | grep -Eq '(curl|wget)[[:space:]]+[^|]*\|[[:space:]]*(sh|bash|zsh|fish|python|python3|perl|ruby)([[:space:]]|$)'; then
  block "remote script execution (curl|sh)"
fi

# --- Database destructive ----------------------------------------------------
# SQL: DROP TABLE / DROP DATABASE / TRUNCATE (case-insensitive, word-boundary).
printf '%s' "$cmd_exp" | grep -Eiq '(^|[^a-zA-Z_])(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]]+TABLE)([[:space:]]|$)' && block "SQL DROP/TRUNCATE"
# Redis.
printf '%s' "$cmd_exp" | grep -Eqi '(^|[[:space:]])(FLUSHALL|FLUSHDB)([[:space:]]|$)' && block "redis FLUSHALL/FLUSHDB"
# Mongo dropDatabase.
printf '%s' "$cmd_exp" | grep -Eqi 'dropDatabase' && block "mongo dropDatabase"

# Not dangerous — allow.
exit 0
