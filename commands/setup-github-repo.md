Initialize GitHub repository for MCP server development with standard structure.

# CREATE CORE FILES

1. Create .gitignore:
   - Python artifacts (__pycache__/, *.pyc, .venv/)
   - Devin settings (.devin/*.local.json)
   - IDE files (.vscode/, .idea/)
   - OS files (.DS_Store, Thumbs.db)
   - Keep .claude/commands/ and .devin/

2. Create pyproject.toml with uv:
   - Use `uv init` to scaffold
   - Add dev dependencies: pytest, pytest-asyncio, pytest-mock, pytest-cov, vulture
   - Add ruff and ty for linting/formatting/type-checking
   - Add watchdog, ipython for development
   - Add sphinx, sphinx-rtd-theme for docs

3. Create Makefile with targets:
   - install: `uv sync`
   - install-dev: `uv sync --extra dev`
   - test: `uv run pytest`
   - test-cov: `uv run pytest --cov`
   - lint: `uv run ruff check .`
   - format: `uv run ruff format .`
   - typecheck: `uv run ty check .`
   - deadcode: `uv run vulture .`
   - clean: remove __pycache__, .venv, build artifacts
   - dev: start dev server with hot reload

# CREATE STRUCTURE

Create the following directory structure:
```
├── tests/
│   ├── __init__.py
│   ├── unit/
│   │   └── __init__.py
│   ├── integration/
│   │   └── __init__.py
│   ├── fixtures/
│   └── conftest.py          # Pytest configuration with common fixtures
├── docs/
│   ├── mcp_server_reference.md  # Tool documentation
│   └── development.md            # Developer guide
├── scripts/
│   ├── run_dev.sh               # Bash hot-reload script
│   └── dev_server.py            # Python hot-reload alternative
├── examples/
│   ├── basic_usage.py           # Usage examples
│   └── README.md                # Examples overview
├── .github/
│   ├── workflows/
│   │   ├── test.yml             # CI testing workflow
│   │   └── lint.yml             # Linting workflow (ruff + ty)
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       └── feature_request.md
└── scratchpad/
    ├── .gitkeep
    └── README.md                # Space for notes
```

# IMPLEMENT KEY FILES

1. Create hot-reload script (scripts/dev_server.py):
   - Watch src/ for changes
   - Clear Python cache
   - Restart server automatically
   - Check dependencies and auth
   - Handle graceful shutdown

2. Create pytest configuration (tests/conftest.py):
   - Mock authentication fixtures
   - Test data fixtures
   - Path setup for imports

3. Create documentation templates:
   - docs/mcp_server_reference.md with tool documentation
   - docs/development.md with setup instructions
   - CONTRIBUTING.md with guidelines

4. Create GitHub workflows:
   - .github/workflows/test.yml for pytest with coverage
   - .github/workflows/lint.yml for ruff check, ruff format --check, ty check

# FINALIZE

1. Update AGENTS.md with project-specific guidance

2. Remind user to run:
   ```bash
   uv sync
   uv sync --extra dev
   uv run pytest
   make dev
   ```

3. Suggest initial commit:
   - Stage all new files
   - Commit with message: "Initialize MCP server repository structure"
