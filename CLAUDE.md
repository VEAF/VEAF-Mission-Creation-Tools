# VEAF Mission Creation Tools — Claude Code Instructions

> This project manipulates DCS mission files (`.miz`) via Python CLI tools at design-time, and injects Lua scripts executed at runtime inside DCS World.

---

## 1. Language and Communication

- **Communication**: Automatically adapt to the language used by the user in their messages.
- **Code & Documentation**: Exclusively use English for functions, variables, comments, docstrings, commit messages, PR descriptions, and all technical project documentation.

---

## 2. AI Behavior (Surgical Mode)

- **RULE N°1 (Surgical Changes)**: NEVER modify adjacent code, comments, or formatting that are not directly related to the request. Do not refactor functional code.
- **RULE N°2 (Absolute Simplicity)**: Produce the minimum volume of code necessary to solve the current problem. Do not add any speculative features or abstractions.
- **RULE N°3 (Zero Assumptions)**: If an instruction is ambiguous, contradictory, or confusing, STOP immediately and ask questions to clarify the intent.

---

## 3. Code Quality and Style (Zero Tolerance)

- **IDE Errors**: No warnings or errors must remain in the editor (Pylance, mypy, ruff, markdown-lint).
- **Static Typing**: Type annotations are mandatory for all functions with explicit return syntax `-> ReturnType`. Use modern unions like `Type | None`.
- **Docstrings**: Write comprehensive docstrings strictly following the Google format (with `Args:`, `Returns:`, `Raises:` sections).

---

## 4. TDD and Behavioral Coverage Rule

- **TDD Cycle**: Always write a failing unit test before implementing any business logic, make the test pass, then refactor.
- **COVERAGE RULE (Zero Regression)**:
  - *New Code*: Every new function, method, or class must be delivered with its corresponding unit tests. Code is considered incomplete without its tests.
  - *Existing Code*: Any modification to existing business logic requires updating existing tests or creating a new test if it is missing.

---

## 5. Git Flow and Commits

- **Branch Management**: All work must be done on feature branches (`feature/*` or `fix/*`) created from `develop-v6`. Never commit directly to `master` or `main`.
- **Commit Messages**: Scrupulously respect the Conventional Commits specification in English (`type(scope): description`).

---

## 6. Backlog and Roadmap Maintenance

- **Real-Time Updates**: `BACKLOG.md` and `ROADMAP.md` files must exactly reflect the progress status of tasks.
- **Archiving**: Move closed tickets that have been completed for more than 3 days from `BACKLOG.md` to `BACKLOG-archive.md`.

---

## 7. Semantic Routing Rules

### Documentation (`.md` files, `doc/` folder)

Jointly analyze both the Python and Lua ecosystems. Explicitly distinguish between scripts running in-game inside DCS and the Python build tooling.

### Python (`src/python/` or `test/python/`)

- **Architecture**: Strictly respect the Worker (`*_worker.py`), Manager (`*_manager.py`), and Data Models (`models.py`) structural pattern.
- **Environment Management**: Dependencies are managed via Poetry. Activate the virtual environment using `poetry shell`.
- **Logger**: Only use the logger from `veaf_libs.logger`. Absolute prohibition of using the native `print()` function.
- **Quality Validation**: Run `poetry run ruff check src/python/ --fix` and `poetry run mypy src/python/veaf-tools/`. Resolve errors rather than adding exclusions.
- **Tests**: Run `poetry run pytest`. Unit tests must match the `test_*.py` pattern and be located in the `test/python/` folder.

### Lua (`src/scripts/veaf/` or `test/lua/`)

- **Environment**: Code written in pure Lua 5.1 executing inside the DCS World environment, without external dependencies.
- **Naming Conventions**: Files named as `veafFeature.lua`, global module table in camelCase (`veafFeature = {}`), and class definitions in PascalCase (`VeafFeature`).
- **Quality Validation**: Run `luacheck --config .luacheckrc src/scripts/veaf/` and `stylua --check src/scripts/veaf/`.
- **Tests**: Run `poetry run test-lua`. Test scripts rely on luaunit and DCS mocks located in `test/lua/test_<module>.lua`.

---

## 8. Default Action Workflow (apply automatically unless told otherwise)

For every action requested by the user, execute these steps in order:

1. **Analyze** the request and identify the impacted files and scope.
   - If the request is exploratory (question, analysis, no code change), stop here.
2. **Create a lot** in `BACKLOG.md`: add a new lot with a unique ID, description, tickets, estimated effort, and status `⬜`. Add it to the Summary table.
3. **Create a branch** from `develop-v6` following the naming convention (`feature/<id>` or `fix/<id>`). If a lot spans multiple tickets, use **one branch and one PR** for the entire lot — do not create a branch per ticket unless explicitly requested.
4. **Implement** the change: code + unit tests (TDD rules apply) + update any relevant documentation in `doc/`.
5. **Run tests** for the impacted language (`poetry run pytest` for Python, `poetry run test-lua` for Lua). Fix any failure before continuing.
6. **Run quality gate** for the impacted language (`poetry run ruff check src/python/ --fix && poetry run mypy src/python/veaf-tools/` for Python; `stylua --check src/scripts/veaf/` for Lua — `luacheck` is not installed, skip it). Resolve all errors before continuing.
7. **Update `CHANGELOG.md`** under `[Unreleased]` with one clear entry.
8. **If the user needs to test manually**: stop and wait for explicit approval ("c'est bon", "go", or equivalent) before continuing. Otherwise, proceed directly.
9. **Commit** all changes (Conventional Commits format in English) and **push** the branch.
10. **Open a PR** targeting `develop-v6` and report the PR URL to the user.
11. **Monitor the PR**: wait for Sourcery review and CI. Address any feedback, then merge when approved.
12. **After merge**: switch back to `develop-v6`, pull, and confirm to the user.

---

## 9. Single Change Checklist (detail of step 4–7 above)

1. Make code changes and write associated unit tests according to TDD rules.
2. Update relevant documentation pages in `doc/` if the change affects user-facing behaviour or configuration.
3. Run all quality validation tools specific to the impacted language (Python or Lua).
4. Update `CHANGELOG.md` under the `[Unreleased]` section (one clear entry per fix or feature).
5. Increment the PATCH version in `pyproject.toml`.
6. Run `poetry install` to update the development environment.

---

## 10. Pull Request Process

After pushing a branch and creating a PR:
- **Do NOT request a Copilot review.** Sourcery reviews PRs automatically.
- Request a review only if Sourcery posts a comment stating it cannot review the PR.

---

## 10. Pipeline Commands

- **Application Build**: `poetry run veaf-build build --version x.y.z`
- **GitHub Publication**: `poetry run veaf-build publish --version x.y.z`
