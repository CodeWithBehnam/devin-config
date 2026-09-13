#!/usr/bin/env bash
# block-exfil.sh — PreToolUse hook for Devin CLI
#
# Blocks network exfiltration: outbound data transfer via curl/wget POST/PUT/
# DELETE/PATCH or data-upload flags. Plain GET downloads are allowed.
#
# What it blocks:
#   - curl/wget with -X POST/PUT/DELETE/PATCH
#   - curl/wget with -d/--data/--data-raw/--data-binary/-F/--form
#   - curl/wget with --upload-file / -T
#   - curl/wget with @file syntax (reading a file into the request body)
#   - nc/ncat/socat connecting outbound (arbitrary TCP tunneling)
#
# What it allows:
#   - Plain curl/wget GET (download to file or stdout)
#   - curl -I (headers only)
#   - npm/pip install (package managers, not raw HTTP)

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_name",""))
except Exception: print("")
')"

block() {
  printf '%s' '{"decision":"block","reason":"Network exfiltration blocked by global Devin hook (block-exfil.sh): '"$1"'"}'
  exit 2
}

case "$tool_name" in
  exec)
    cmd="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("command","")
    print(v if isinstance(v,str) else "")
except Exception: print("")
')"
    [ -z "$cmd" ] && exit 0

    # Detect curl/wget with data-upload or write-method flags.
    if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(curl|wget)[[:space:]]'; then
      # POST/PUT/DELETE/PATCH method.
      if printf '%s' "$cmd" | grep -Eqi '(^|[[:space:]])-X[[:space:]]+(POST|PUT|DELETE|PATCH)'; then
        block "curl/wget with -X POST/PUT/DELETE/PATCH"
      fi
      # Data payload flags (curl + wget).
      if printf '%s' "$cmd" | grep -Eqi '(^|[[:space:]])(-d|--data|--data-raw|--data-binary|--data-urlencode|-F|--form|--post-data|--post-file)([[:space:]]|=)'; then
        block "curl/wget with data payload flag"
      fi
      # File upload.
      if printf '%s' "$cmd" | grep -Eqi '(^|[[:space:]])(--upload-file|-T)([[:space:]]|=)'; then
        block "curl/wget --upload-file"
      fi
      # @file syntax (read file into request body).
      if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(-d|--data)[[:space:]]+@'; then
        block "curl/wget reading file into request body (@file)"
      fi
    fi

    # nc/ncat/socat outbound connections (arbitrary TCP tunneling).
    if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(nc|ncat)[[:space:]]+[^-]'; then
      block "nc/ncat outbound connection"
    fi
    if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])socat[[:space:]].*TCP'; then
      block "socat TCP connection"
    fi
    ;;

  webfetch)
    # webfetch is GET-only, but block URLs with very long query strings
    # (potential data smuggling via URL params).
    url="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); v=d.get("tool_input",{}).get("url","")
    print(v if isinstance(v,str) else "")
except Exception: print("")
')"
    [ -z "$url" ] && exit 0
    # Block if query string is suspiciously long (>500 chars = likely data smuggling).
    qs="$(printf '%s' "$url" | sed 's/[^?]*//' | tr -d '\n')"
    if [ ${#qs} -gt 500 ]; then
      block "webfetch URL with very long query string (possible data smuggling)"
    fi
    ;;
esac

exit 0
