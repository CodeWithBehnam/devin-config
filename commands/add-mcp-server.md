Add the MCP server named "$ARGUMENTS" to Devin CLI.

# DETERMINE SERVER TYPE

1. Check if server is local or remote:
   - Local: Look for server.py, setup.py, package.json in current directory
   - Remote: URL starts with https://

2. Identify OS and language requirements:
   - Mac/Linux: Use `uv run python` for Python commands
   - Windows/WSL: May need `python.exe` or `python`
   - Check current OS: !`uname -s 2>/dev/null || echo "Windows"`

# ADD SERVER

1. For local servers, determine correct command:
   - Python on Mac/Linux: `devin mcp add $ARGUMENTS -- uv run python server.py`
   - Python on Windows/WSL: `devin mcp add $ARGUMENTS -- python.exe server.py`
   - Node.js: `devin mcp add $ARGUMENTS -- bun index.js`

2. For remote servers:
   - HTTP: `devin mcp add --transport http $ARGUMENTS <url>`
   - SSE: `devin mcp add --transport sse $ARGUMENTS <url>`
   - With auth: Add `-H "Authorization: Bearer KEY"`

3. Set scope if needed:
   - Local (default): Current project only
   - Project: `-s project` (shares via .mcp.json)
   - User: `-s user` (all projects)

# VERIFY AND ACTIVATE

1. List servers: `devin mcp list`
2. Get details: `devin mcp get $ARGUMENTS`
3. **IMPORTANT**: Restart Devin for new servers to work:
   - Exit current session (Ctrl+D or type `exit`)
   - Start new session: `devin`
4. For OAuth servers: Type `/mcp` to authenticate

# MANAGE SERVERS

To remove a server later:
```bash
# Remove by name
devin mcp remove $ARGUMENTS

# Remove with specific scope
devin mcp remove -s project $ARGUMENTS
devin mcp remove -s user $ARGUMENTS
```

After removing, restart Devin for changes to take effect.

# TROUBLESHOOTING

1. Server not appearing after adding:
   - Did you restart Devin?
   - Check scope: local vs project vs user
   - Verify with: `devin mcp list`

2. Python command issues:
   - Mac/Linux: Use `uv run python`
   - Windows: Try `python`, `python.exe`, or `py`
   - WSL: Often requires `python.exe`
   - Virtual env: Use `uv venv` to create, `uv run` to execute

3. Common errors:
   - 405 Error: Try HTTP instead of SSE transport
   - Module not found: Install dependencies first with `uv pip install`
   - Permission denied: Check file permissions
