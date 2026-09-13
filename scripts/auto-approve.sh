#!/usr/bin/env bash
# auto-approve.sh — PermissionRequest hook for Devin CLI
#
# Auto-approves safe read-only commands so you're not prompted for every
# harmless operation. Anything not matched here falls through to the normal
# permission prompt (exit 0 = defer decision).

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

approve() {
  printf '%s' '{"decision":"approve"}'
  exit 0
}

# Only auto-approve exec commands (file reads/writes still go through normal flow).
[ "$tool_name" = "exec" ] || exit 0

cmd="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("command","")
    print(v if isinstance(v,str) else "")
except Exception: print("")
')"

[ -z "$cmd" ] && exit 0

# --- Safe read-only command prefixes ---
# git read-only
printf '%s' "$cmd" | grep -Eq '^git[[:space:]]+(status|log|diff|show|branch([[:space:]]|$)|remote|rev-parse|ls-files|blame|describe|tag([[:space:]]|-l))' && approve
# ls / file listing
printf '%s' "$cmd" | grep -Eq '^ls([[:space:]]|$)' && approve
# cat / head / tail / less on non-secret files (secrets already blocked by PreToolUse)
printf '%s' "$cmd" | grep -Eq '^(cat|head|tail|less|more|bat|wc|file|stat|du|df)([[:space:]]|$)' && approve
# find / which / whereis / type
printf '%s' "$cmd" | grep -Eq '^(find|which|whereis|type|command)([[:space:]]|$)' && approve
# echo / printf / true
printf '%s' "$cmd" | grep -Eq '^(echo|printf|true)([[:space:]]|$)' && approve
# pwd / date / whoami / hostname
printf '%s' "$cmd" | grep -Eq '^(pwd|date|whoami|hostname|uname)([[:space:]]|$)' && approve
# test / [
printf '%s' "$cmd" | grep -Eq '^(\[|test)([[:space:]]|$)' && approve
# npm/pnpm/yarn test + lint + typecheck (read-only, no install)
printf '%s' "$cmd" | grep -Eq '^(npm|pnpm|yarn)[[:space:]]+(run[[:space:]]+)?(test|lint|typecheck|tsc|check)([[:space:]]|$)' && approve
# python -c is blocked by block-banned-tools.sh (use 'uv run python -c' instead)
# rg / grep / ag (search — secrets already filtered)
printf '%s' "$cmd" | grep -Eq '^(rg|grep|ag|ack)([[:space:]]|$)' && approve

# Not in the safe list — defer to normal permission prompt.
exit 0
