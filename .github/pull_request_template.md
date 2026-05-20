## Description

<!-- Describe what this PR does and why. Link any related issue. -->

Closes #

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring (no behaviour change)
- [ ] Documentation
- [ ] Chore / tooling / CI

## Quality checklist

### Lua changes
- [ ] `stylua --check src/scripts/veaf/` passes (version **2.4.0**)
- [ ] Lua tests pass for affected modules
- [ ] New public API documented in `doc/LUA_API_REFERENCE.md`

### Python changes
- [ ] `poetry run ruff check src/python/veaf-tools` passes
- [ ] `poetry run mypy src/python/veaf-tools` passes
- [ ] `poetry run pytest` passes

### All changes
- [ ] `CHANGELOG.md` updated (if user-visible)
