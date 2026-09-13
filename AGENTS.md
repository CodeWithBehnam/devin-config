# Global Rules

Personal preferences that apply to every Devin CLI session, regardless of
project. Project-level `AGENTS.md` files are loaded on top of these.

## Commits

- Write commit messages in conventional commit format:
 `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
 `build:`, `ci:`, `style:`
- Keep the subject line under 72 chars, imperative mood ("add" not "added")
- Body explains *why*, not *what* - the diff already shows what changed

## Code style

- Prefer functional and declarative patterns over imperative code
- Use pure functions where practical; avoid mutation of shared state
- Prefer `map` / `filter` / `reduce` over `for` loops with accumulator variables
- Prefer early returns over nested `if/else` chains
- Prefer composition over inheritance
- Never use em-dashes or en-dashes in any output. Use a regular hyphen, comma,
  colon, or parentheses instead. This is enforced by a hook that blocks
  writes and edits containing em-dashes.

## Python

- Use `uv` (Astral) for all Python tooling - never `pip`, `pipx`, `virtualenv`, `venv`, `poetry`, or `pipenv` directly
- Create environments: `uv venv`
- Install packages: `uv pip install <pkg>` (or `uv add <pkg>` in a project with `pyproject.toml`)
- Run scripts: `uv run <script>` (auto-resolves the project venv)
- Manage Python versions: `uv python install <version>`, `uv python pin <version>`
- New projects: `uv init` to scaffold `pyproject.toml`
- Sync dependencies: `uv sync` (reads `pyproject.toml` / `uv.lock`)
- Prefer `pyproject.toml` + `uv.lock` over `requirements.txt`

### Python linting & formatting

- **Ruff** - linter and formatter. Replaces flake8, isort, black, pyupgrade.
 Never use those tools directly. Configure in `[tool.ruff]` in `pyproject.toml`.
 - Lint: `uv run ruff check .`
 - Format: `uv run ruff format .`
 - Fix: `uv run ruff check --fix .`
- **Ty** - type checker from Astral. Replaces mypy / pyright for type checking.
 - Check: `uv run ty check .`
- **Vulture** - dead code finder. Finds unused code that linters miss.
 - Run: `uv run vulture .`
- Run all three before declaring a Python task complete: ruff check + ruff format + ty check + vulture

## JavaScript / TypeScript

- Use `bun` for all JS/TS tooling - never `npm`, `pnpm`, `yarn`, or `npx` directly
- Install packages: `bun add <pkg>` (or `bun add -d <pkg>` for dev deps)
- Remove packages: `bun remove <pkg>`
- Install all deps: `bun install`
- Run scripts: `bun run <script>` (or just `bun <script>`)
- Run files: `bun <file.ts>` (no separate transpile step needed)
- Create projects: `bun init`
- Update deps: `bun update <pkg>` (or `bun update` for all)
- Prefer `bun.lockb` + `package.json` over other lockfiles

## Writing

- Never use AI slop patterns in any text you write (docs, READMEs, comments,
  commit messages, PR descriptions). This is enforced by a hook that blocks
  writes containing banned words and phrases.
- Banned words: delve, foster, leverage, utilize, facilitate, empower,
  streamline, robust, cutting-edge, tapestry, realm, beacon, multifaceted,
  meticulous, intricate, paramount, transformative, elevate, embark,
  supercharge, harness, ever-evolving, and all conjugations.
- Banned phrases: "here is the thing", "let me be clear", "what nobody tells
  you", "in conclusion", "at the end of the day", "the reality is", "lets
  dive in", "it is worth noting", and similar filler.
- When writing prose (docs, READMEs, PR descriptions), run the /no-ai-slop
  skill on the draft before writing the file. The hook will block the write
  if slop patterns remain.
- Use plain, direct language. Concrete details over abstractions. Active
  voice. Short sentences. No filler.

## Guardrails

Active guardrails are enforced by hooks (see `~/.config/devin/HOOKS.md`).
The agent does not need to enforce these - the hooks block violations
automatically. The agent should not attempt to work around them.

## New repository setup

When creating or initializing a new git repository, always include:

- **MIT License** - add a `LICENSE` file with the MIT license text and the
 author's name/year
- **README.md** - always create one. It must include:
 - Project title and one-line description
 - **Problem statement** - what problem this repo solves and why it exists
 - **Tags / labels** - a `## Tags` section listing relevant keywords/topics
 (e.g. `youtube`, `automation`, `python`) for discoverability
 - **Getting started** - clone + install + run instructions
 - **Mermaid diagram** - at least one `mermaid` code block visualizing
 architecture, data flow, or the main workflow
 - **Project tree** - a `## Project Structure` section with an ASCII tree
 showing the directory layout (use `tree` or hand-format)
- **GitHub repo settings** - after pushing:
 - Set the **About** section (description + website + topics) via
 `gh repo edit --description "..." --add-topic tag1 --add-topic tag2`
 - Add **issue templates** in `.github/ISSUE_TEMPLATE/`:
 - `bug_report.md` - bug report with repro steps, expected/actual, env
 - `feature_request.md` - feature request with problem, proposal, alternatives
 - Add a **lint CI workflow** at `.github/workflows/lint.yml`:
 - Python: `uv run ruff check .`, `uv run ruff format --check .`, `uv run ty check .`
 - JS/TS: `bun run lint` (or `bunx biome check .` if no lint script exists)
 - Add a **test CI workflow** at `.github/workflows/test.yml`:
 - Python: `uv run pytest --cov`
 - JS/TS: `bun test`

Reusable templates for LICENSE, README.md, issue templates, and CI workflows
are in `~/.config/devin/templates/`. Copy and adapt them - don't start from
scratch.
