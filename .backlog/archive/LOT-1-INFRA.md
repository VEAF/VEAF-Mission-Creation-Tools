# Lot 1 — INFRA: Python quality gate + CI

Status: ✅ done

**Goal**: Python quality gate working locally and in CI before any feature work.
**Branch**: `feature/infra-poetry-quality-gate` → PR → `develop-v6`

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| INFRA-001 | Create `pyproject.toml` with Poetry, migrate `requirements.txt` | chore | 45 min | — | [x] |
| INFRA-002 | Configure ruff (lint + format) in `pyproject.toml` | chore | 20 min | INFRA-001 | [x] |
| INFRA-003 | Configure mypy in `pyproject.toml` | chore | 30 min | INFRA-001 | [x] |
| INFRA-004 | Fix all ruff/mypy violations in `src/python` | fix | 60 min | INFRA-002, INFRA-003 | [x] |
| INFRA-005 | Configure pytest globally (`testpaths`, coverage) | chore | 30 min | INFRA-001 | [x] |
| INFRA-006 | Add `python-quality` job in `.github/workflows/` | chore | 30 min | INFRA-001 | [x] |

**Raw total: 215 min → estimated (×1.15): ~250 min (~4h15)**

<details>
<summary>Ticket details</summary>

**INFRA-001 — pyproject.toml Poetry**
Migrate `requirements.txt` (lupa, rich, typer, pyyaml, Pillow, astral, pydantic, avwx-engine) to Poetry groups (`[tool.poetry.dependencies]` for runtime, `[tool.poetry.group.dev.dependencies]` for quality tools). Verify PyInstaller (`veaf-tools.spec`) still works with the Poetry environment.
⚠️ The existing `.venv` must remain compatible with the PyInstaller workflow.

**INFRA-002 — ruff configuration**
`[tool.ruff]` section in `pyproject.toml`. Enabled rules: `E`, `F`, `W`, `I` (import sorting), `UP` (pyupgrade). Exclude `luadata/` (bundled third-party library). Line length: 120.

**INFRA-003 — mypy configuration**
`[tool.mypy]` section in `pyproject.toml`. Strict on `src/python/veaf-tools/` except `luadata/`. Configure stubs for untyped libraries (pyyaml → `types-PyYAML`, lupa → ignore).

**INFRA-004 — Fix existing violations**
Fix all ruff + mypy errors. The 2 TODOs in `presets_manager.py`:
- Line 18: missing modulation → implement or convert to `# TODO(FEAT-xxx): add modulation`
- Line 450: deferred GUI editor → convert to `# TODO(FEAT-001): implement in interactive mode`

**INFRA-005 — Unified pytest**
`testpaths = ["src/python/veaf-tools", "test"]`. pytest auto-discovers existing unittest tests (`test_presets.py`, `luadata/__test__.py`). Add `pytest-cov` for coverage. Minimum target: 60% on `src/python/veaf-tools/`.

**INFRA-006 — CI python-quality**
New file `.github/workflows/python-ci.yml` (or extra job in `lua-ci.yml`). Steps:
1. `actions/checkout@v4`
2. `actions/setup-python@v5` with Python 3.11
3. `pip install poetry` + `poetry install`
4. `poetry run ruff check src/python`
5. `poetry run ruff format --check src/python`
6. `poetry run mypy src/python`
7. `poetry run pytest`

</details>
