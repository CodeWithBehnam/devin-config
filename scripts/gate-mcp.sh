#!/usr/bin/env bash
# gate-mcp.sh — PreToolUse hook for Devin CLI
#
# Blocks MCP tools that have external side effects (create/update/delete/submit
# on github, slack, linear, etc.). Read-only MCP tools (list, get, search, read)
# are allowed. This prevents the agent from filing issues, posting messages,
# or modifying external systems without your explicit approval.
#
# Tool name format: mcp__<server>__<tool>

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

# Only check MCP tools.
printf '%s' "$tool_name" | grep -Eq '^mcp__' || exit 0

block() {
  printf '%s' '{"decision":"block","reason":"MCP write tool blocked by global Devin hook (gate-mcp.sh): '"$1"' — ask the user to run this manually."}'
  exit 2
}

# Extract the tool name suffix (after mcp__server__).
tool_suffix="$(printf '%s' "$tool_name" | sed 's/^mcp__[^_]*__//')"

# --- Write/mutate keywords that indicate external side effects ---
# Matches if any underscore-delimited segment of the tool name is a write verb.
# e.g. "devin_session_create" → segments ["devin","session","create"] → "create" matches.
write_re='(^|_)(create|update|delete|remove|destroy|submit|send|post|add|edit|modify|set|merge|close|archive|assign|transition|move|upload|publish|deploy|install|enable|disable|remediate|manage|tag|invite|kick|page|ingest|interact|terminate|archive)(_|$)'

if printf '%s' "$tool_suffix" | grep -Eqi "$write_re"; then
  block "$tool_name"
fi

# --- Server-specific write tool names that don't match the generic prefix ---
# GitHub: review tools, create_*, etc. already caught above. Add specific ones.
case "$tool_name" in
  mcp__github__create_pull_request*|mcp__github__merge_pull_request*|mcp__github__add_comment*|mcp__github__create_issue*|mcp__github__update_issue*|mcp__github__create_review*|mcp__github__create_branch*|mcp__github__delete_branch*|mcp__github__create_or_update_file*)
    block "$tool_name"
    ;;
esac

# Read-only — allow.
exit 0
