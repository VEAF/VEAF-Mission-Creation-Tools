# VEAF Project: DCS Mission Creation Tools

> This project manipulates DCS mission files (`.miz`) via Python CLI tools at design-time, and injects Lua scripts executed at runtime inside DCS World.  
> Read and apply the generic rules from `.github/copilot-instructions-generic.md` first.

## SEMANTIC ROUTING RULES (Working Memory)

**IF you are working on DOCUMENTATION (`.md` files, `doc/` folder):**

- Jointly analyze both the Python and Lua ecosystems. Explicitly distinguish between scripts running in-game inside DCS and the Python build tooling.

**IF you are working on PYTHON (`src/python/` or `test/python/`):**

- **Architecture**: Strictly respect the Worker (`*_worker.py`), Manager (`*_manager.py`), and Data Models (`models.py`) structural pattern.
- **Environment Management**: Dependencies are managed via Poetry. Activate the virtual environment using `poetry shell`.
- **Logger**: Only use the logger from `veaf_libs.logger`. Absolute prohibition of using the native `print()` function.
- **Quality Validation**: Run `poetry run ruff check src/python/ --fix` and `poetry run mypy src/python/veaf-tools/`. Resolve errors rather than adding exclusions.
- **Tests**: Run `poetry run pytest`. Unit tests must match the `test_*.py` pattern and be located in the `test/python/` folder.

**IF you are working on LUA (`src/scripts/veaf/` or `test/lua/`):**

- **Environment**: Code written in pure Lua 5.1 executing inside the DCS World environment, without external dependencies.
- **Naming Conventions**: Files named as `veafFeature.lua`, global module table in camelCase (`veafFeature = {}`), and class definitions in PascalCase (`VeafFeature`).
- **Quality Validation**: Run `luacheck --config .luacheckrc src/scripts/veaf/` and `stylua --check src/scripts/veaf/`.
- **Tests**: Run `poetry run test-lua`. Test scripts rely on luaunit and DCS mocks located in `test/lua/test_<module>.lua`.

## SINGLE CHANGE PROCESS (Linear Checklist)

For each task or fix, rigorously apply these steps in order:

1. Make code changes and write associated unit tests according to TDD rules.
2. Run all quality validation tools specific to the impacted language (Python or Lua).
3. Manually update `CHANGELOG.md` under the `[Unreleased]` section (one clear entry per fix or feature).
4. Increment the PATCH version in `pyproject.toml`.
5. Run the `poetry install` command to update the development environment.

## PULL REQUEST PROCESS

After pushing a branch and creating a PR:
- **Do NOT request a Copilot review.** Sourcery reviews PRs automatically.
- Request a Copilot review **only if** Sourcery posts a comment stating it cannot review the PR.

## PIPELINE COMMANDS

- **Application Build**: `poetry run veaf-build build --version x.y.z`
- **GitHub Publication**: `poetry run veaf-build publish --version x.y.z`

 