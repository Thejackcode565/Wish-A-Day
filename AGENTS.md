# Repository Guidelines

## Project Structure & Module Organization
- `app/` holds the FastAPI backend: `main.py` (app entry), `routes/` (HTTP endpoints), `services/` (business logic), `models.py` (SQLAlchemy), `schemas.py` (Pydantic).
- `tests/` contains backend tests and pytest config (`conftest.py`, `test_*.py`).
- `scripts/` contains operational helpers like `init_db.py`.
- `frontend/` is a Vite + React + TypeScript UI with its own `package.json`, `src/`, and `public/`.
- `app/uploads/` is the default image storage path (configured via `.env`).

## Build, Test, and Development Commands
Backend (from repo root):
- `pip install -e ".[dev]"` installs backend dependencies.
- `python scripts/init_db.py` initializes the database.
- `uvicorn app.main:app --reload --port 8000` runs the API locally.
- `pytest -v` runs backend tests; `pytest --cov=app --cov-report=html` adds coverage.
- `black app/ tests/`, `isort app/ tests/`, `mypy app/` for formatting, imports, and typing.

Frontend (from `frontend/`):
- `npm i` installs UI dependencies.
- `npm run dev` starts the Vite dev server.
- `npm run build` builds the UI for production.
- `npm run test` (or `npm run test:watch`) runs Vitest.
- `npm run lint` runs ESLint.

## Coding Style & Naming Conventions
- Python uses Black with a 100-char line length and isort’s Black profile (`pyproject.toml`).
- Mypy is configured with `disallow_untyped_defs = true`; new functions should have type hints.
- Follow existing module naming: snake_case for Python files and `test_*.py` for tests.
- Frontend code is linted by ESLint (`frontend/eslint.config.js`); keep React components in PascalCase and hooks prefixed with `use`.

## Testing Guidelines
- Backend tests live in `tests/` and follow pytest’s `test_*.py` and `test_*` naming rules.
- Frontend tests run via Vitest; colocate tests near UI code when practical.
- Add or update tests when changing API behavior, validation, or UI flows.

## Commit & Pull Request Guidelines
- Recent commits are short, sentence-style summaries (often starting with verbs like “Add”, “Fix”, or “Remove”).
- Keep commits focused; prefer one logical change per commit.
- PRs should include a concise description, testing notes, and UI screenshots for frontend changes.
- Link related issues or tickets when applicable.

## Security & Configuration Tips
- Copy `.env.example` to `.env` and do not commit secrets.
- If changing upload handling, confirm `UPLOAD_DIR` and size limits in `.env`.
