#!/usr/bin/env bash
# session-context.sh — SessionStart hook for Devin CLI
#
# Injects project context and policy reminders at the start of every session.
# Prints additionalContext JSON on stdout (per Devin hook spec).

set -u

proj="${DEVIN_PROJECT_DIR:-}"

context="Devin session started. Active guardrails (enforced by hooks, not just guidance):
- SECRETS: Reading .env, SSH keys, credential files, and env-dump commands is BLOCKED.
- DANGEROUS COMMANDS: git push --force, reset --hard, clean -f, branch -D, sudo, rm -rf outside the project dir, shutdown/reboot, curl|sh, DROP TABLE, FLUSHALL are BLOCKED.
- WRITES: Writing files outside the project dir (or /tmp) is BLOCKED.
- NETWORK: curl/wget POST/PUT/DELETE and data-upload flags are BLOCKED. GET downloads are allowed.
- MCP: MCP tools with external side effects (create/update/delete on github, slack, linear, etc.) are BLOCKED.
- AUDIT: All exec, write, and edit calls are logged to ~/.config/devin/logs/.

Project dir: ${proj:-(unknown — DEVIN_PROJECT_DIR not set)}.
Read AGENTS.md in the project root for project-specific conventions before starting work."

# Escape for JSON.
escaped="$(printf '%s' "$context" | /usr/bin/python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}' "$escaped"
exit 0
