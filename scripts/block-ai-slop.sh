#!/usr/bin/env bash
# block-ai-slop.sh - PostToolUse hook for Devin CLI
#
# Checks write/edit content for common AI slop patterns after the tool
# runs. If patterns are found, blocks with a message telling the agent
# to run the /no-ai-slop skill on the content before writing again.
#
# Reads the PostToolUse event JSON on stdin. Exits 2 to block.

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

case "$tool_name" in
  write|edit|apply_patch) ;;
  *) exit 0 ;;
esac

# Extract the content that was written
content="$(printf '%s' "$payload" | /usr/bin/python3 -c '
import sys, json

d = json.load(sys.stdin)
ti = d.get("tool_input", {}) or {}

text = ""
if "content" in ti:
    text = ti["content"] or ""
elif "new_string" in ti:
    text = ti["new_string"] or ""
elif "patch" in ti:
    text = ti["patch"] or ""

print(text)
')"

[ -z "$content" ] && exit 0

# Check for AI slop patterns using Python
slop_found="$(printf '%s' "$content" | /usr/bin/python3 -c '
import sys, re

text = sys.stdin.read()

# Banned words (from no-ai-slop SKILL.md)
# Match word stems to catch "fosters", "leveraging", "utilized", etc.
banned_stems = [
    "delve", "foster", "leverage", "utilize", "facilitate", "empower",
    "streamline", "robust", "cutting-edge", "paradigm shift",
    "game changer", "this is huge", "this changes everything",
    "tapestry", "realm", "beacon", "multifaceted", "meticulous",
    "intricate", "paramount", "transformative", "elevate", "embark",
    "supercharge", "harness", "ever-evolving",
]

# Slop phrases (from no-ai-slop SKILL.md)
slop_phrases = [
    "here is the thing",
    "let me be clear",
    "what nobody tells you",
    "the part everyone misses",
    "what most people get wrong",
    "marks a pivotal moment",
    "a testament to",
    "stands as a testament",
    "plays a vital role",
    "solidifies its position",
    "underscores its significance",
    "experts agree",
    "industry reports suggest",
    "studies show",
    "widely regarded as",
    "in conclusion",
    "at the end of the day",
    "when it comes to",
    "at its core",
    "in todays world",
    "in the age of",
    "the reality is",
    "the truth is",
    "in terms of",
    "going forward",
    "lets dive in",
    "it is worth noting",
    "it is important to note",
]

text_lower = text.lower()

# Remove code blocks and inline code from checking
# (words inside backticks are code, not prose)
no_code = re.sub(r"`[^`]*`", "", text_lower)
no_code = re.sub(r"```[\s\S]*?```", "", no_code)

found = []
for stem in banned_stems:
    # Match the stem with optional suffixes (s, ed, ing, es, d)
    pattern = r"\b" + re.escape(stem) + r"(s|ed|ing|es|d)?\b"
    if re.search(pattern, no_code):
        found.append(stem)

for phrase in slop_phrases:
    if phrase in no_code:
        found.append(phrase)

if found:
    unique = list(dict.fromkeys(found))
    print(",".join(unique[:10]))
')"

if [ -n "$slop_found" ] && [ "$slop_found" != "" ]; then
  printf '%s' '{"decision":"block","reason":"AI slop detected in written content. Patterns found: '"${slop_found}"'. Run the /no-ai-slop skill on this content before writing it again. Replace banned words with plain language and remove slop phrases."}'
  exit 2
fi

exit 0
