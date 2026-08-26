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

### Runtime debugging (DCS log)

When investigating a **runtime / in-game** issue (scripts not loading, missing VEAF
radio menu, a feature misbehaving in DCS), read the **DCS log** to see what actually
happened at runtime — script load order, module initialization, and Lua errors.

- Location: `%USERPROFILE%\Saved Games\DCS\Logs\dcs.log` (or `DCS.openbeta`).
  On this machine: `C:\Users\David\Saved Games\DCS\Logs\dcs.log`.
- Useful greps: `VEAF`, `SCRIPTING`, `STATIC VEAF scripts loading` / `STATIC Mission scripts loading`, `initialize`, `ERROR`.

---

## 3. Code Quality and Style (Zero Tolerance)

- **IDE Errors**: No warnings or errors must remain in the editor (Pylance, mypy, ruff, markdown-lint).
- **Static Typing**: Type annotations are mandatory for all functions with explicit return syntax `-> ReturnType`. Use modern unions like `Type | None`.
- **Docstrings**: Write comprehensive docstrings strictly following the Google format (with `Args:`, `Returns:`, `Raises:` sections).

### Quality Ratchet Policy (mypy exclusions + coverage gate)

The mypy `ignore_errors` overrides in `pyproject.toml` (the excluded workers list) and the `--cov-fail-under` coverage gate are **technical debt to erode, never to grow**. They are eroded lot-by-lot, not in a single big-bang:

- **mypy exclusions**: any lot that *substantially* edits a worker still listed under `ignore_errors` MUST drop that worker's entry as part of its Definition of Done, and fix the surfaced type errors. Never add a new entry to the excluded list.
  - *Substantially* = touching the worker's logic: adding or changing a function, method, branch, or signature. A purely mechanical edit (a string/i18n change, an import reorder, a comment) does **not** trigger the obligation.
- **Coverage gate**: any lot that adds tests MUST bump `--cov-fail-under` so the gate never sits more than **~2 points below** actual measured coverage. The number only ever goes up.

These are enforcement obligations on **every** lot, not a separate clean-up task — the dedicated `QUALITY-GATE` lot only mops up whatever workers no other lot has reopened.

---

## 4. TDD and Behavioral Coverage Rule

- **TDD Cycle**: Always write a failing unit test before implementing any business logic, make the test pass, then refactor.
- **COVERAGE RULE (Zero Regression)**:
  - *New Code*: Every new function, method, or class must be delivered with its corresponding unit tests. Code is considered incomplete without its tests.
  - *Existing Code*: Any modification to existing business logic requires updating existing tests or creating a new test if it is missing.

---

## 5. Git Flow and Commits

- **Branch Management**: All work must be done on feature branches (`feature/*` or `fix/*`) created from `develop`. Never commit directly to `master` or `main`.
- **Commit Messages**: Scrupulously respect the Conventional Commits specification in English (`type(scope): description`).

---

## 6. Backlog and Roadmap Maintenance

- **Real-Time Updates**: the `.backlog/` directory and `ROADMAP.md` must exactly reflect task status. Each active lot is a directory `.backlog/<LOT-ID>/` (PRD.md + tickets); `.backlog/README.md` is the lot index, maintained by hand.
- **Archiving**: move lots closed for more than 3 days from `.backlog/<LOT-ID>/` to a compact `.backlog/archive/<LOT-ID>.md`.

---

## 7. Semantic Routing Rules

### Documentation (`.md` files, `doc/` folder)

Jointly analyze both the Python and Lua ecosystems. Explicitly distinguish between scripts running in-game inside DCS and the Python build tooling.

- **Quality gate**: run `poetry run docs-check` after touching anything under `doc/` or `mkdocs.yml`. The CI `Docs Check` job runs the same command; it fails on a broken relative link, a cross-page anchor the target does not expose, a cross-page anchor derived from a heading, a French page with no `.en.md`, or a page absent from the `nav`.
- **Both languages, always**: a new page ships as `page.md` (French, the default locale) **and** `page.en.md`, and goes into the `mkdocs.yml` `nav` with its `nav_translations` entry. A page reachable only through an inline link is invisible to anyone browsing the menu.
- **Anchor convention**: any section linked from another page carries an **explicit English** anchor — `## Couverture {#coverage}` / `## Coverage {#coverage}`. The anchor is identical across languages; the heading text stays in the page's language. Never link a heading-derived slug: it breaks on the next reword and differs between FR and EN.
- **Never hand-write a version** in a page header: the repo keeps a readable range (`6.11.x`) and the deploy workflow stamps the shipped version (`veaf_build/docs_version_stamp.py`).

### Python (`src/python/` or `test/python/`)

- **Architecture**: Strictly respect the Worker (`*_worker.py`), Manager (`*_manager.py`), and Data Models (`models.py`) structural pattern.
- **Environment Management**: Dependencies are managed via Poetry. Activate the virtual environment using `poetry shell`.
- **Logger**: Only use the logger from `veaf_libs.logger`. Absolute prohibition of using the native `print()` function.
- **Quality Validation**: Run `poetry run ruff check src/python/ test/python/ veaf_build/ --fix`, `poetry run ruff format --check src/python/ test/python/ veaf_build/` and `poetry run mypy src/python/veaf-tools/`. Resolve errors rather than adding exclusions. These are the CI commands exactly (`python-quality.yml`) — ruff covers the **whole** Python tree, mypy only the shipped package (tests use loose typing on purpose).
- **Tests**: Run `poetry run pytest`. Unit tests must match the `test_*.py` pattern and be located in the `test/python/` folder.

### Lua (`src/scripts/veaf/` or `test/lua/`)

- **Environment**: Code written in pure Lua 5.1 executing inside the DCS World environment, without external dependencies.
- **Positions**: before writing anything that places an object, read `docs/agents/dcs-coordinates.md` — the runtime is not even internally consistent about what `y` means.
- **Naming Conventions**: Files named as `veafFeature.lua`, global module table in camelCase (`veafFeature = {}`), and class definitions in PascalCase (`VeafFeature`).
- **Quality Validation**: Run `luacheck --config .luacheckrc src/scripts/veaf/` and `stylua --check src/scripts/veaf/ test/lua/`.
- **Tests**: Run `poetry run test-lua`. Test scripts rely on luaunit and DCS mocks located in `test/lua/test_<module>.lua`. Line coverage is available via `poetry run test-lua --coverage` (luacov); the CI `lua-coverage` job enforces a ratchet floor with `--cov-fail-under` — like the Python coverage gate, the number only ever goes up.

---

## 8. Default Action Workflow (apply automatically unless told otherwise)

For every action requested by the user, execute these steps in order:

0. **Sync first (MANDATORY)**: at the start of any conversation or any new chantier within an existing conversation, **systematically** make sure the working folder you are using (worktree or not) is up to date with GitHub before reading the backlog or doing anything else — `git fetch` then `git pull --ff-only` on `develop` (or rebase your branch onto the latest `origin/develop`). Never reason about "what's left to do" or start work from a stale local checkout.
1. **Analyze** the request and identify the impacted files and scope.
   - If the request is exploratory (question, analysis, no code change), stop here.
   - **When starting work on a ticket, first restate it in 1–3 sentences.** What it is and what
     "done" means, before any tool call. The point is that the user can catch a misread before the
     work is built on it, not after.
2. **Create a lot** under `.backlog/<LOT-ID>/`: write `PRD.md` (Status `⬜ ready`) and one `tickets/<NN>-<slug>.md` per ticket. Add a row to `.backlog/README.md`.
3. **Create a branch** from `develop` following the naming convention (`feature/<id>` or `fix/<id>`). If a lot spans multiple tickets, use **one branch and one PR** for the entire lot — do not create a branch per ticket unless explicitly requested.
4. **Implement** the change: code + unit tests (TDD rules apply) + update any relevant documentation in `doc/`.
5. **Run tests** for the impacted language (`poetry run pytest` for Python, `poetry run test-lua` for Lua). Fix any failure before continuing.
6. **Run quality gate** for the impacted language (`poetry run ruff check src/python/ test/python/ veaf_build/ --fix && poetry run ruff format --check src/python/ test/python/ veaf_build/ && poetry run mypy src/python/veaf-tools/` for Python; `stylua --check src/scripts/veaf/ test/lua/` and `luacheck --config .luacheckrc src/scripts/veaf/` for Lua). Both Lua tools are enforced by the CI Lua gate (`.github/workflows/lua-ci.yml`); if `luacheck` is not installed locally (e.g. on Windows), rely on the CI check — do **not** treat the gate as skippable. Resolve all errors before continuing.
7. **Update `CHANGELOG.md`** under `[Unreleased]` with one clear entry, appended at the **end** of that section (appending conflicts far less than prepending when two PRs land together). Do **not** create a version heading and do **not** bump the version — see §9.5.
8. **If the user needs to test manually**: stop and wait for explicit approval ("c'est bon", "go", or equivalent) before continuing. Otherwise, proceed directly.
9. **Commit** all changes (Conventional Commits format in English) and **push** the branch.
10. **Open a PR** targeting `develop` and report the PR URL to the user.
11. **Monitor the PR**: wait for Sourcery review and CI. Address any feedback, then merge when approved.
12. **After merge**: switch back to `develop`, pull, and confirm to the user.

---

## 9. Single Change Checklist (detail of step 4–7 above)

1. Make code changes and write associated unit tests according to TDD rules.
2. Update relevant documentation pages in `doc/` if the change affects user-facing behaviour or configuration.
3. Run all quality validation tools specific to the impacted language (Python or Lua).
4. Update `CHANGELOG.md` under the `[Unreleased]` section (one clear entry per fix or feature), appended at the end of the section.
5. **Do not touch the version.** `pyproject.toml` and both agent manifests — `plugin/.claude-plugin/plugin.json` (Claude Code) and `plugin/gemini-extension.json` (Gemini CLI) — move **only in a release commit**, together. The plugin and the tools ship as one product and `test_plugin_version.py` enforces the match, so a release bumps all three or fails the suite.

   *Why a PR must not bump it:* the rule used to require a PATCH bump on every change, which made any two concurrent PRs conflict by construction — on `pyproject.toml`, both manifests and the `CHANGELOG.md` heading, none of which carries engineering content. Measured over the 10 merges following 6.16.0: 9 touched the changelog, 8 touched the version files. One documentation-only PR needed **three rebases in one hour**, renumbering 6.16.5 → .8 as `develop` took each number first. The numbers bought little — 6.16.0 consolidated **47 patch versions, none of them ever published**.
6. Run `poetry install` to update the development environment.
7. **Defaults lockstep**: if the change touches how `convert-v5` or `lua_config_generator` produce `mission.yaml` (comments, config blocks, module keys, structure), update `src/defaults/mission-folder/mission.yaml` in the **same lot** so the shipped default stays aligned with the generated output.

---

## 10. Pull Request Process

After pushing a branch and creating a PR:
- **Do NOT request a Copilot review.** Sourcery reviews PRs automatically.
- Request a review only if Sourcery posts a comment stating it cannot review the PR.
- **One lot per PR stays the rule, but Sourcery stops reviewing past ~150 000 characters of diff.**
  If a lot is heading over that, split it into sequenced PRs with the shared groundwork first.
  Measured on PR #759 (172 905 characters), which merged with no third-party review; the two lots
  after it were split on purpose and were reviewed.

- **There is also a weekly budget: 250 000 diff characters across all PRs.** When it runs out Sourcery
  answers with a rate-limit comment instead of a review, so a PR opened late in the week gets no
  third-party review at all. Hit on 2026-08-24: #795 was reviewed and #796, opened 24 minutes later,
  got the rate-limit message. Twenty PRs had been opened since 18 August, about 12 000 changed lines —
  on the order of 600 000 characters, so at this cadence the budget covers roughly the first third of
  the week.

  **What this means in practice, and why it needs saying:** a silent Sourcery is not a misconfiguration
  to go hunting for, and it is not a CLEAN either. `merge au vert` requires CI green **and** a clean
  review; when the quota is spent, the second half is unavailable and the merge decision is David's,
  not a rule's. Say so plainly rather than merging on CI alone or waiting for a review that will not
  come.

  Sourcery does not review automatically in every case even with budget left — a `@sourcery-ai review`
  comment on the PR triggers it, and that is worth trying **before** concluding anything about the
  installation.

---

## 10. Pipeline Commands

- **Application Build**: `poetry run veaf-build build --version x.y.z`
- **GitHub Publication**: `poetry run veaf-build publish --version x.y.z`

---

## Agent skills

### Issue tracker

Lots/PRDs/tickets live as markdown under `.backlog/<LOT-ID>/` (active) and
`.backlog/archive/<LOT-ID>.md` (completed). See `docs/agents/issue-tracker.md`.

### Triage labels

Single `Status:` vocabulary (⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix),
mapped to Matt's triage roles. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.

### DCS coordinates

`x`/`y`/`z` mean **different things** in a mission table and in the runtime scripting API, and getting
them confused raises no error — only a wrong position. Read `docs/agents/dcs-coordinates.md` before
writing code that places anything.
