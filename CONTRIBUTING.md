# Contributing to VEAF Mission Creation Tools

Thank you for contributing! This document explains how to set up your environment, submit changes, and follow the project's conventions.

> 🇫🇷 Guide du développeur complet : [doc/developer/GUIDE.md](doc/developer/GUIDE.md)

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
develop        ← integration branch (all PRs target this)
  └── feature/xxx ← your work
  └── fix/xxx     ← bug fixes
main              ← stable releases only
```

1. Fork or create a branch from `develop`
2. Make your changes (see [quality checklist](#quality-checklist) below)
3. Open a PR against `develop`
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
- **Split a diff over ~150 000 characters into sequenced PRs** (the shared groundwork first).
  Sourcery, which reviews every PR automatically, refuses a diff past that size — PR #759 measured
  172 905 characters and shipped with no third-party review at all
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

Two ways in, and they land in the same place:

- **From GitHub** — [open an issue](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues) and
  choose the *Bug Report* or *Feature Request* template.
- **From Discord** — `/bug` on the [VEAF Discord](https://www.veaf.org/discord) opens a form and
  files the issue for you, under a bot account. No GitHub account needed. See
  [Getting help](doc/SUPPORT.en.md#bug).

For questions and real-time discussion, the Discord is the fastest route.

### Triaging an issue that a bot filed {#bot-filed}

An issue labelled `filed-by-bot` arrives through `/bug`, and reads differently from a hand-written
one — usefully so, and with one trap:

- **The body is measured, not narrated.** The versions come from a pasted `doctor` block, the
  `file:line` from a stack trace resolved against the repository, the log excerpt from the rules
  catalogue, the *Prior art* section from a sweep of the issues, `.backlog/` and `ROADMAP.md`. What
  is missing is stated as missing rather than guessed.
- **A comment headed ⚠️ is a machine's guess.** It carries a suspected file and line and it has been
  verified by nobody. Read it as a lead, never as a diagnosis — closing a real report on it is the
  one failure the labelling exists to prevent.
- **The reporter is on Discord, not on GitHub.** He is credited in the body and the issue links back
  to his thread. Answering *on the issue* reaches him: the bot carries comments and the closure back
  into that thread. He cannot answer from there — to add something, he writes in the thread and a
  maintainer carries it over.
- **The attachments are described, not attached.** GitHub has no API to attach a file to an issue;
  small text files are quoted inside the issue, and everything else is listed with its size and
  SHA-256. If you need the raw file, ask in the thread.

### What happens to an issue {#issue-intake}

GitHub Issues are the **intake desk**, not the work tracker. The work itself lives in
`.backlog/<LOT-ID>/` inside the repository (see
[`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)), because a lot needs a PRD,
tickets and a status that travel with the code.

So an issue has exactly two futures: it is **picked up** — a lot is created and the issue is
closed pointing at that lot — or it stays open as a report nobody has taken yet. An open
issue therefore means "recorded, not started"; it is never a half-done piece of work.

Three triage labels say where a re-read left an old issue:

| Label | Meaning |
|-------|---------|
| `v5-era` | Opened before v6. The framework it describes has since been rewritten, so the report must be re-read against v6 before anyone acts on it. |
| `probably-done` | v6 appears to already do this. The evidence is recorded in the triage table; the issue is kept open until someone confirms and closes it. |
| `still-valid` | Re-read against v6: the feature really is missing and the need still holds. |
| `verify` | Cannot be settled by reading the code — needs a reproduction, usually in DCS. |

**Security vulnerabilities** — do **not** open a public issue. See [SECURITY.md](SECURITY.md).
