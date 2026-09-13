#!/usr/bin/env bash
# block-em-dashes.sh - PreToolUse hook for Devin CLI
#
# Blocks em-dashes (U+2014) and en-dashes (U+2013) in file content
# being written or edited, and in shell commands. The agent must use
# regular hyphens, commas, parentheses, or colons instead.
#
# Reads the PreToolUse event JSON on stdin. Exits 2 to block.

set -u

payload="$(cat)"

# Use Python to extract tool name and check for em/en-dashes in one pass.
# This avoids macOS grep -P incompatibility.
result="$(printf '%s' "$payload" | /usr/bin/python3 -c '
import sys, json

d = json.load(sys.stdin)
tool = d.get("tool_name", "")
ti = d.get("tool_input", {}) or {}

# Pick the field to check based on tool type.
text = ""
if tool == "write":
    text = ti.get("content", "") or ""
elif tool == "edit":
    text = ti.get("new_string", "") or ""
elif tool == "apply_patch":
    text = ti.get("patch", "") or ""
elif tool == "exec":
    text = ti.get("command", "") or ""

# Check for em-dash (U+2014) or en-dash (U+2013).
em_dash = "\u2014"
en_dash = "\u2013"
has_em = em_dash in text
has_en = en_dash in text

if has_em or has_en:
    # Output which dash type was found.
    found = []
    if has_em:
        found.append("em-dash")
    if has_en:
        found.append("en-dash")
    print("BLOCK:" + ",".join(found))
else:
    print("OK")
')"

case "$result" in
  BLOCK:*)
    dash_type="${result#BLOCK:}"
    printf '%s' '{"decision":"block","reason":"'"${dash_type}"' blocked by global Devin hook (block-em-dashes.sh): use a hyphen, comma, colon, or parentheses instead."}'
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
