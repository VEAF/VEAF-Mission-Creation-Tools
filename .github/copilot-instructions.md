# VEAF Project: DCS Mission Creation Tools

> This project manipulates DCS mission files (`.miz`) via Python CLI tools at design-time, and injects Lua scripts executed at runtime inside DCS World.  
> Read and apply the generic rules from `.github/copilot-instructions-generic.md` first.

> **`CLAUDE.md` at the repository root is the authoritative version of these rules.** This file
> repeats the part of them that Copilot can see, because Copilot reads only `.github/`. When the
> two disagree, `CLAUDE.md` wins and this file is the one to fix. It has drifted before: until
> 2026-09-21 it still told every contributor to bump the PATCH version on each change, which
> `CLAUDE.md` §9.5 had forbidden — and its quality commands were narrower than the ones CI runs,
> so following them produced a green desk and a red pull request.

## SEMANTIC ROUTING RULES (Working Memory)

**IF you are working on DOCUMENTATION (`.md` files, `doc/` folder):**

- Jointly analyze both the Python and Lua ecosystems. Explicitly distinguish between scripts running in-game inside DCS and the Python build tooling.

**IF you are working on PYTHON (`src/python/` or `test/python/`):**

- **Architecture**: Strictly respect the Worker (`*_worker.py`), Manager (`*_manager.py`), and Data Models (`models.py`) structural pattern.
- **Environment Management**: Dependencies are managed via Poetry. Activate the virtual environment using `poetry shell`.
- **Logger**: Only use the logger from `veaf_libs.logger`. Absolute prohibition of using the native `print()` function.
- **Quality Validation**: Run `poetry run ruff check src/python/ test/python/ veaf_build/ --fix`, `poetry run ruff format --check src/python/ test/python/ veaf_build/` and `poetry run mypy src/python/veaf-tools/`. Resolve errors rather than adding exclusions. These are the CI commands exactly (`python-quality.yml`): ruff covers the **whole** Python tree, mypy only the shipped package. A narrower `ruff check src/python/` passes on your machine and fails in CI.
- **Tests**: Run `poetry run pytest`. Unit tests must match the `test_*.py` pattern and be located in the `test/python/` folder.

**IF you are working on LUA (`src/scripts/veaf/` or `test/lua/`):**

- **Environment**: Code written in pure Lua 5.1 executing inside the DCS World environment, without external dependencies.
- **Naming Conventions**: Files named as `veafFeature.lua`, global module table in camelCase (`veafFeature = {}`), and class definitions in PascalCase (`VeafFeature`).
- **Quality Validation**: Run `luacheck --config .luacheckrc src/scripts/veaf/` and `stylua --check src/scripts/veaf/ test/lua/`. The test folder is part of the formatter's scope, and CI checks it.
- **Tests**: Run `poetry run test-lua`. Test scripts rely on luaunit and DCS mocks located in `test/lua/test_<module>.lua`.

## SINGLE CHANGE PROCESS (Linear Checklist)

For each task or fix, rigorously apply these steps in order:

1. Make code changes and write associated unit tests according to TDD rules.
2. Run all quality validation tools specific to the impacted language (Python or Lua).
3. Manually update `CHANGELOG.md` under the `[Unreleased]` section (one clear entry per fix or feature), **appended at the end** of that section — appending conflicts far less than prepending when two pull requests land together.
4. **Do not touch the version.** `pyproject.toml` and both agent manifests (`plugin/.claude-plugin/plugin.json`, `plugin/gemini-extension.json`) move only in a release commit, together; `test_plugin_version.py` enforces the match. This step used to say the opposite — bump the PATCH on every change — which made any two concurrent pull requests conflict by construction on files carrying no engineering content. See `CLAUDE.md` §9.5 for the measurements behind the change.
5. Run the `poetry install` command to update the development environment.

## PULL REQUEST PROCESS

After pushing a branch and creating a PR:
- **Do NOT request a Copilot review.** Sourcery reviews PRs automatically.
- Request a Copilot review **only if** Sourcery posts a comment stating it cannot review the PR.

## PIPELINE COMMANDS

- **Application Build**: `poetry run veaf-build build --version x.y.z`
- **GitHub Publication**: `poetry run veaf-build publish --version x.y.z`

 