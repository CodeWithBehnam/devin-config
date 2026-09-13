#!/usr/bin/env bash
# audit-log.sh — PostToolUse hook for Devin CLI
#
# Appends a line for every exec / write / edit / apply_patch / notebook_edit
# call so you have a forensic record of what the agent did. Never blocks.
#
# Log location: ~/.config/devin/logs/audit-YYYY-MM-DD.log
# Format: ISO8601 | session_id | tool | success | summary

set -u

log_dir="$HOME/.config/devin/logs"
mkdir -p "$log_dir"
log_file="$log_dir/audit-$(date +%Y-%m-%d).log"

payload="$(cat)"

# Extract fields via python (handles JSON safely).
read -r ts sid tool success summary <<EOF
$(printf '%s' "$payload" | /usr/bin/python3 -c '
import sys, json, datetime
d = json.load(sys.stdin)
ts = datetime.datetime.now().isoformat(timespec="seconds")
sid = d.get("session_id", "")[:12]
tool = d.get("tool_name", "")
ti = d.get("tool_input", {}) or {}
# Build a short summary of what was done.
if tool == "exec":
    s = (ti.get("command","") or "")[:200]
elif tool in ("write", "edit", "apply_patch", "notebook_edit"):
    s = (ti.get("file_path","") or "")[:200]
else:
    s = json.dumps(ti)[:200]
# PostToolUse has tool_response with success flag.
tr = d.get("tool_response", {}) or {}
success = "ok" if tr.get("success", True) else "FAIL"
print(ts, sid, tool, success, s)
' 2>/dev/null)
EOF

# Sanitize summary (strip newlines) and write.
summary_clean="$(printf '%s' "$summary" | tr '\n' ' ' | tr '|' '/' )"
printf '%s | %s | %s | %s | %s\n' "$ts" "$sid" "$tool" "$success" "$summary_clean" >> "$log_file"

exit 0
