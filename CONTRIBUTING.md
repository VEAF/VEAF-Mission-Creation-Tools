# Contributing to VEAF Mission Creation Tools

Thank you for contributing! This document explains how to set up your environment, submit changes, and follow the project's conventions.

> 🇫🇷 Guide du développeur complet : [doc/developer/fr/GUIDE.md](doc/developer/fr/GUIDE.md)

---

## Table of Contents

1. [Getting started](#getting-started)
2. [Development workflow](#development-workflow)
3. [Commit convention](#commit-convention)
4. [Pull request process](#pull-request-process)
5. [Quality checklist](#quality-checklist)
6. [Reporting bugs & requesting features](#reporting-bugs--requesting-features)

---

## Getting started

The fastest way is the **DevContainer** — zero local install required:

```
VS Code → Ctrl+Shift+P → "Dev Containers: Reopen in Container"
```

Or **GitHub Codespaces** — click **Code → Codespaces → New codespace** on the repo page.

For manual setup, see the [Developer Guide](doc/developer/GUIDE.md#development-environment).

---

## Development workflow

```
develop-v6        ← integration branch (all PRs target this)
  └── feature/xxx ← your work
  └── fix/xxx     ← bug fixes
main              ← stable releases only
```

1. Fork or create a branch from `develop-v6`
2. Make your changes (see [quality checklist](#quality-checklist) below)
3. Open a PR against `develop-v6`
4. Address review comments — CI must be green before merge

---

## Commit convention

```
type(scope): short description (≤72 chars)

Optional body — wrap at 100 chars.
```

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `chore` | Maintenance, deps, tooling |
| `docs` | Documentation only |
| `test` | Adding or fixing tests |
| `refactor` | Code change, no behaviour change |
| `style` | Formatting only |

**Scope examples:** `spawn`, `qra`, `weather`, `devcontainer`, `ci`, `deps`

---

## Pull request process

- Keep PRs focused — one concern per PR
- Title follows the commit convention above
- Fill in the PR template (auto-populated when you open a PR)
- Link any related issue in the PR description (`Closes #123`)
- At least one approving review required before merge

---

## Quality checklist

### Lua changes
- [ ] `stylua --check src/scripts/veaf/` passes (version **2.4.0**)
- [ ] All Lua tests pass: `lua5.1 test/lua/test_<module>.lua`
- [ ] New public functions documented in `doc/LUA_API_REFERENCE.md`

### Python changes
- [ ] `poetry run ruff check src/python/veaf-tools` passes
- [ ] `poetry run ruff format --check src/python/veaf-tools` passes
- [ ] `poetry run mypy src/python/veaf-tools` passes
- [ ] `poetry run pytest` passes
- [ ] New behaviour covered by tests

### All changes
- [ ] `CHANGELOG.md` updated for any user-visible change

---

## Reporting bugs & requesting features

Use [GitHub Issues](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues):

- **Bug report** → choose the *Bug Report* template
- **Feature request** → choose the *Feature Request* template

For questions and real-time discussion, join the [VEAF Discord](https://www.veaf.org/discord).

**Security vulnerabilities** — do **not** open a public issue. See [SECURITY.md](SECURITY.md).
