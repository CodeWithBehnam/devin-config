#!/usr/bin/env bash
# block-secrets.sh — PreToolUse hook for Devin CLI
#
# Blocks tools from reading, writing, or dumping secrets:
#   - .env / .env.* files
#   - SSH keys and private key material (~/.ssh, *.pem, *.key, id_rsa, id_ed25519)
#   - Credential files (credentials.json, service-account JSON, *.p12, ~/.aws/credentials)
#   - Shell env-dump commands (env, printenv, export -p)
#
# Reads the PreToolUse event JSON on stdin. Exits 2 to block (per Devin hook spec),
# printing a JSON decision/reason on stdout so the agent sees why.

set -u

payload="$(cat)"

tool_name="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_name",""))
except Exception:
    print("")
')"

# Extract the field we care about for this tool.
extract() {
  /usr/bin/python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
ti = d.get('tool_input', {}) or {}
field = sys.argv[2]
val = ti.get(field, '')
print(val if isinstance(val, str) else json.dumps(val))
" "$payload" "$1"
}

block() {
  printf '%s' '{"decision":"block","reason":"Secret access blocked by global Devin hook (block-secrets.sh): '"$1"'"}'
  exit 2
}

# --- Patterns that indicate secret material ---
# File paths / basenames we never want the agent to read or write.
secret_path_re='(^|/)(\.env(\..*)?|id_rsa|id_ed25519|id_ecdsa|id_dsa|.*\.pem|.*\.key|.*\.p12|credentials\.json|service-account.*\.json|service_account.*\.json)(/|$)'
secret_dir_re='(^|/)(\.ssh|\.aws|\.gnupg|\.config/gcloud)(/|$)'

# Shell commands that dump live environment secrets.
env_dump_re='(^|[[:space:]|&;])(env|printenv|export -p)([[:space:]]|$)'

case "$tool_name" in
  read|write|edit|apply_patch|notebook_read|notebook_edit)
    fp="$(extract file_path)"
    [ -z "$fp" ] && fp="$(extract path)"
    if [ -n "$fp" ]; then
      # Expand ~ so ~/.ssh matches.
      fp_exp="${fp/#\~/$HOME}"
      if printf '%s' "$fp_exp" | grep -Eq "$secret_path_re"; then
        block "file path matches secret pattern: $fp"
      fi
      if printf '%s' "$fp_exp" | grep -Eq "$secret_dir_re"; then
        block "path is inside a secret directory: $fp"
      fi
    fi
    ;;
  exec)
    cmd="$(extract command)"
    if [ -n "$cmd" ]; then
      if printf '%s' "$cmd" | grep -Eq "$env_dump_re"; then
        block "command dumps live environment secrets: $cmd"
      fi
      # Expand ~ in the command so ~/.ssh matches.
      cmd_exp="${cmd//\~/$HOME}"
      # Block any reader/editor invoked on a secret path or a path inside a secret dir.
      # secret_basename matches the filename portion (no leading-slash anchor).
      secret_basename='(\.env(\..*)?|id_rsa|id_ed25519|id_ecdsa|id_dsa|.*\.pem|.*\.key|.*\.p12|credentials\.json|service-account.*\.json|service_account.*\.json)$'
      secret_dir_inline='(\.ssh|\.aws|\.gnupg|\.config/gcloud)/'
      if printf '%s' "$cmd_exp" | grep -Eq "(^|[[:space:]])(cat|less|more|head|tail|bat|vim|nvim|nano|vi|cp|mv|scp|rsync|dd)[[:space:]]+[^|&;]*($secret_basename|$secret_dir_inline)"; then
        block "command reads a secret path: $cmd"
      fi
      # Block redirects that write secrets to stdout, e.g. `cat ~/.env` or `< ~/.env`.
      if printf '%s' "$cmd_exp" | grep -Eq "(<|[[:space:]])($secret_basename|$secret_dir_inline)"; then
        block "command references a secret path: $cmd"
      fi
    fi
    ;;
  grep|glob)
    # Searching inside secret dirs can leak contents via matches.
    sp="$(extract path)"
    [ -z "$sp" ] && sp="$(extract glob_pattern)"
    if [ -n "$sp" ]; then
      sp_exp="${sp/#\~/$HOME}"
      if printf '%s' "$sp_exp" | grep -Eq "$secret_dir_re"; then
        block "search targets a secret directory: $sp"
      fi
    fi
    ;;
esac

# Not a secret access — allow.
exit 0
