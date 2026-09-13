#!/usr/bin/env bash
# block-banned-tools.sh — PreToolUse hook for Devin CLI
#
# Enforces tooling preferences by blocking banned package managers and
# interpreters. The agent must use the approved alternatives:
#
#   Python:  uv (Astral) instead of pip, pip3, python -m pip, virtualenv,
#            venv, poetry, pipenv, pipx, and bare python3/python execution
#   JS/TS:   bun instead of npm, pnpm, yarn, npx
#
# Matching: banned tools are only blocked when they appear as the COMMAND
# (at start of the command string, or after a separator: |, &, ;). This
# prevents false positives like `uv pip install` (pip is a uv subcommand)
# or `uv run python -c '...'` (python is an argument to uv run).
#
# Reads the PreToolUse event JSON on stdin. Exits 2 to block.

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

[ "$tool_name" = "exec" ] || exit 0

cmd="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("command","")
    print(v if isinstance(v,str) else "")
except Exception: print("")
')"

[ -z "$cmd" ] && exit 0

block() {
  printf '%s' '{"decision":"block","reason":"Banned tool blocked by global Devin hook (block-banned-tools.sh): '"$1"'"}'
  exit 2
}

# Separator: start-of-string, or after |, &, ; (with optional trailing spaces).
# This ensures we only match the tool as a COMMAND, not as an argument to uv/bun.
SEP='(^|[|&;][[:space:]]*)'

# --- Python: banned package managers -----------------------------------------
printf '%s' "$cmd" | grep -Eq "${SEP}pip3?([[:space:]]|$)" && block "pip/pip3 — use 'uv pip install' or 'uv add' instead"
printf '%s' "$cmd" | grep -Eq "${SEP}python3?[[:space:]]+-m[[:space:]]+pip([[:space:]]|$)" && block "python -m pip — use 'uv pip install' instead"
printf '%s' "$cmd" | grep -Eq "${SEP}virtualenv([[:space:]]|$)" && block "virtualenv — use 'uv venv' instead"
printf '%s' "$cmd" | grep -Eq "${SEP}python3?[[:space:]]+-m[[:space:]]+venv([[:space:]]|$)" && block "python -m venv — use 'uv venv' instead"
printf '%s' "$cmd" | grep -Eq "${SEP}(poetry|pipenv|pipx)([[:space:]]|$)" && block "poetry/pipenv/pipx — use 'uv' instead"

# --- Python: bare interpreter execution --------------------------------------
# Block python3/python used to run scripts or -c one-liners.
# The agent should use 'uv run <script>' or 'uv run python -c "..."'.
printf '%s' "$cmd" | grep -Eq "${SEP}python3?([[:space:]]|$)" && block "bare python3/python — use 'uv run <script>' or 'uv run python -c' instead"

# --- JS/TS: banned package managers & runners --------------------------------
printf '%s' "$cmd" | grep -Eq "${SEP}(npm|pnpm|yarn|npx)([[:space:]]|$)" && block "npm/pnpm/yarn/npx — use 'bun' instead (bun add, bun install, bun run)"

exit 0
