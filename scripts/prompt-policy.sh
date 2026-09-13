#!/usr/bin/env bash
# prompt-policy.sh — UserPromptSubmit hook for Devin CLI
#
# Injects a short standing-policy reminder on every user prompt so the agent
# keeps the guardrails in mind throughout the session.

set -u

policy="POLICY REMINDER (enforced by hooks): Never commit secrets. Never force-push (use --force-with-lease if needed). Never run destructive commands (rm -rf outside repo, sudo, reset --hard, DROP TABLE). Run the test suite before declaring a task complete. All exec/write/edit calls are audit-logged."

escaped="$(printf '%s' "$policy" | /usr/bin/python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')"

printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}' "$escaped"
exit 0
