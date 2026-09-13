# Devin CLI Hooks & Guardrails

Global hook configuration for Devin CLI, installed at the user level so it
applies to every project on this machine.

## Location

| Path | Purpose |
|------|---------|
| `~/.config/devin/config.json` | Hook registrations (the `"hooks"` key) |
| `~/.config/devin/scripts/*.sh` | Hook scripts (one per concern) |
| `~/.config/devin/logs/audit-YYYY-MM-DD.log` | Audit log output (daily rotation) |

## Hook inventory

Nine scripts across five lifecycle events. All scripts are executable bash,
read the event JSON on stdin, and exit `2` with a `decision: block` JSON on
stdout when they want to deny an action.

### PreToolUse (fires before a tool runs)

| # | Script | Matcher | What it blocks |
|---|--------|---------|----------------|
| 1 | `block-secrets.sh` | `read\|write\|edit\|apply_patch\|notebook_read\|notebook_edit\|exec\|grep\|glob` | Reads of `.env`, `.env.*`, SSH keys (`id_rsa`, `id_ed25519`, `*.pem`, `*.key`), credential files (`credentials.json`, `service-account*.json`, `*.p12`), paths inside `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config/gcloud`. Shell commands `env`, `printenv`, `export -p`, and readers (`cat`, `less`, `head`, `tail`, `vim`, `nano`, `cp`, `mv`, `scp`, `rsync`, `dd`) pointed at any secret path. Searches scoped to a secret directory. |
| 2 | `block-dangerous.sh` | `exec` | Destructive git: `push --force` (allows `--force-with-lease`), `reset --hard`, `clean -f`, `branch -D`, `checkout .` / `restore .`, `filter-branch`, `reflog expire --all`. Destructive filesystem: `rm -rf` on `/`, `/*`, `~`, `$HOME`, `.`, `..`, or any absolute path outside `DEVIN_PROJECT_DIR`; `chmod -R` / `chown -R` on system dirs; `dd` to disk devices; `mkfs` / `fdisk` / `diskutil eraseDisk`; fork bombs. System: `sudo` (any), `shutdown` / `reboot` / `halt` / `poweroff`, `kill -9 1`, `launchctl bootout`, writes into `/etc` `/System` `/usr` `/bin` `/sbin`. Remote execution: `curl\|sh`, `wget\|bash`, etc. Database: `DROP TABLE` / `DROP DATABASE` / `TRUNCATE`, Redis `FLUSHALL` / `FLUSHDB`, Mongo `dropDatabase`. |
| 3 | `block-writes-outside.sh` | `write\|edit\|apply_patch\|notebook_edit` | Writes to any path outside `DEVIN_PROJECT_DIR` (except `/tmp`). Prevents the agent from modifying `~/.zshrc`, system configs, or its own hook scripts. |
| 4 | `block-exfil.sh` | `exec\|webfetch` | `curl` / `wget` with `-X POST/PUT/DELETE/PATCH`, data payload flags (`-d`, `--data`, `--data-binary`, `--post-data`, `--post-file`, `-F`, `--form`), `--upload-file` / `-T`, `@file` syntax, `nc` / `ncat` outbound, `socat TCP`. `webfetch` URLs with query strings longer than 500 chars (data smuggling). Plain GET downloads are allowed. |
| 5 | `gate-mcp.sh` | `mcp__*` | MCP tools whose name contains a write verb: `create`, `update`, `delete`, `remove`, `destroy`, `submit`, `send`, `post`, `add`, `edit`, `modify`, `set`, `merge`, `close`, `archive`, `assign`, `transition`, `move`, `upload`, `publish`, `deploy`, `install`, `enable`, `disable`, `remediate`, `manage`, `tag`, `invite`, `kick`, `page`, `ingest`, `interact`, `terminate`. Read-only MCP tools (get, list, search, read, ask) are allowed. |
| 6 | `block-banned-tools.sh` | `exec` | Enforces tooling preferences. **Python**: blocks `pip`, `pip3`, `python -m pip`, `virtualenv`, `python -m venv`, `poetry`, `pipenv`, `pipx`, and bare `python3`/`python` execution (use `uv run` instead). **JS/TS**: blocks `npm`, `pnpm`, `yarn`, `npx` (use `bun` instead). Only matches tools as the *command* (at start or after `\|`/`&&`/`;`), not as arguments to `uv`/`bun` — so `uv pip install` and `uv run python -c` are allowed. |

### PostToolUse (fires after a tool finishes)

| # | Script | Matcher | What it does |
|---|--------|---------|--------------|
| 6 | `audit-log.sh` | `exec\|write\|edit\|apply_patch\|notebook_edit` | Appends a line to `~/.config/devin/logs/audit-YYYY-MM-DD.log` for every shell command and file write. Format: `ISO8601 \| session_id(12) \| tool \| ok/FAIL \| summary(200)`. Never blocks. |

### SessionStart (fires when a session begins)

| # | Script | What it does |
|---|--------|--------------|
| 7 | `session-context.sh` | Injects a summary of all active guardrails + the project dir into the agent's context so it knows the rules from turn one. |

### UserPromptSubmit (fires when the user sends a message)

| # | Script | What it does |
|---|--------|--------------|
| 8 | `prompt-policy.sh` | Injects a concise policy reminder on every prompt: never commit secrets, never force-push, never run destructive commands, run tests before declaring done, all actions are audit-logged. |

### PermissionRequest (fires when a permission decision is needed)

| # | Script | Matcher | What it does |
|---|--------|---------|--------------|
| 9 | `auto-approve.sh` | `exec` | Auto-approves safe read-only commands so you're not prompted for every harmless op: `git status/log/diff/show/branch/remote`, `ls`, `cat`, `head`, `tail`, `less`, `wc`, `file`, `stat`, `find`, `which`, `echo`, `printf`, `pwd`, `date`, `npm/pnpm/yarn test/lint/typecheck/tsc/check` (note: npm/pnpm/yarn are blocked by `block-banned-tools.sh` — use `bun` equivalents), `rg/grep/ag/ack`. `python3 -c` is NOT auto-approved (blocked by `block-banned-tools.sh`). Anything not matched defers to the normal permission prompt. |

## How hooks work

Each hook is a bash script that:

1. Receives the event JSON on **stdin** (tool name, tool input, session id, etc.)
2. Inspects the relevant field (`file_path` for file tools, `command` for `exec`, etc.)
3. Exits with a code that controls the outcome:
   - `0` — allow (or defer to the next hook / normal flow)
   - `2` — **block** (the action is denied; the agent sees the reason)
   - Other — error (logged but doesn't block)
4. For block decisions, prints a JSON object on stdout:
   ```json
   {"decision":"block","reason":"..."}
   ```
5. For context injection (SessionStart, UserPromptSubmit, PostToolUse), prints:
   ```json
   {"hookSpecificOutput":{"hookEventName":"...","additionalContext":"..."}}
   ```

Hooks from all config levels (user + project + project-local) are **collected
and all run** — they don't override each other. A block from any hook denies
the action.

## Config structure

All hooks live under the `"hooks"` key in `~/.config/devin/config.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "...", "hooks": [{ "type": "command", "command": "...", "timeout": 5 }] }
    ],
    "PostToolUse": [...],
    "SessionStart": [...],
    "UserPromptSubmit": [...],
    "PermissionRequest": [...]
  }
}
```

The `matcher` field is a **regex** matched against the tool name (not a glob).
`""` or omitted matches all tools. MCP tools appear as `mcp__<server>__<tool>`.

## Verification

In any Devin session, run the slash command:

```
/hooks
```

This lists all loaded hooks and their source files so you can confirm the
config is picked up.

## Limitations

These hooks are **defense-in-depth, not a sandbox**. They catch direct,
common vectors but can be bypassed by indirect paths:

- `python3 -c "open('.env').read()"` — Python reading a file directly
- `bash -c "git reset --hard"` — Nested shell hiding the pattern
- Symlinks pointing to secret files
- MCP tools that don't match the write-verb blocklist

For hard guarantees, pair these hooks with filesystem sandboxing (the
`"sandbox"` key in user config) and restricted permission scopes.

## Extending

To add a new blocklist entry:

- **Secrets**: edit `secret_path_re` / `secret_dir_re` / `secret_basename` in
  `block-secrets.sh`
- **Dangerous commands**: add a new `grep -Eq` + `block` line in
  `block-dangerous.sh`
- **MCP gate**: add the verb to the `write_re` regex in `gate-mcp.sh`
- **Auto-approve**: add a new `grep -Eq ... && approve` line in
  `auto-approve.sh`

To add a brand-new hook:

1. Write the script in `~/.config/devin/scripts/`
2. `chmod +x` it
3. Add an entry under the right event in `~/.config/devin/config.json`
4. Test it with a synthetic stdin payload (see the test commands in the session
   that built these hooks)
