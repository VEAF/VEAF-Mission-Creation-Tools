# Copilot Instructions — Generic (Python Projects)

## Language

- **Communication**: Adapt to the user's language based on their messages
- **Code & docs**: English (functions, variables, comments, docstrings, all markdown project docs, commit messages, PR descriptions)

---

## AI Behavior Guidelines

> These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

---

## Code Style

- **Zero errors/warnings in VSCode**: no Pylance errors, no mypy errors, no markdown linting warnings
- **Type annotations required**: all functions must have type hints with `-> ReturnType`. Use `Path | None` for unions (Python 3.10+ syntax)
- **Linting**: Ruff with 120 char line length
- **Type checking**: mypy strict mode. All imports must be typed or added to `[[tool.mypy.overrides]]` in `pyproject.toml`
- **Docstrings**: Google style with `Args:`, `Returns:`, `Raises:` sections
- **Patterns**: Follow existing patterns in codebase
- **Markdown**: proper heading levels and formatting (no markdown-lint error in VS Code)

---

## Quality Standards

- **Zero tolerance**: NO errors allowed in mypy, ruff, or pytest
- All type stubs must be installed and all mypy errors resolved
- All tests must pass (100%)

---

## Git Flow

- `develop` — integration branch; all work is merged here via PR
- `main` (or `master`) — production-ready releases only
- `feature/*` — new features branched from `develop`
- `fix/*` — bug fixes branched from `develop`

### Branch naming

```text
feature/short-description
fix/short-description
```

### Rules

- All work happens on feature branches. Never commit directly to `main`/`master`.
- Always push after committing.
- **Always run `git branch` (or `git status`) before any git operation** (commit, cherry-pick, merge, push, etc.) to confirm you are on the intended branch.
- **Never merge branches directly** (no `git merge`, no `git push` to `main`/`master` or `develop`). Always go through a PR.

### Commit messages

Follow **Conventional Commits** (`type(scope): description` in English):

- `feat(api): add rate limiting middleware`
- `fix(parser): handle timeout`
- `chore(deps): upgrade dependency`
- `docs(api): document endpoint`
- `test(module): add tests`
- `refactor(module): extract logic`

---

## Testing

### TDD (Test-Driven Development)

Always write tests **before** implementing functionality:

1. Write a failing test that describes the expected behaviour
2. Implement the minimum code to make it pass
3. Refactor, keeping tests green

### Test structure

- Tests in `tests/test_*.py`
- Keep tests updated with code changes
- Test files mirror the source structure

### Coverage targets

- Core / business logic: **≥ 90%**
- API / integration layers: **≥ 80%**
- CLI / thin wrappers: **≥ 70%**
- **Global minimum: ≥ 80%**

Each project may define more specific per-module thresholds.

---

## Workflow

### Development cycle

1. Analyze the codebase and add tickets to `BACKLOG.md` (format: `XXX-NNN`, priorities P1–P4, dates, estimates — see **Estimation** below)
2. If a ticket represents a new feature, major initiative, or strategic shift, also add it to `ROADMAP.md` under "Not yet planned"
3. Group related tickets into **batches** (lots) — a batch is a coherent set of work items delivered together
4. For each batch, agree on a target version (`major.minor`) and add the batch to the roadmap
5. Work on each batch in git-flow: feature branch → PR on `develop`
6. Update `CHANGELOG.md` continuously as work progresses (under `[Unreleased]`)
7. On release: bump version, stamp `CHANGELOG.md`, open a PR to `main`/`master`

### Keeping docs in sync

- `BACKLOG.md` and `ROADMAP.md` must be **kept up to date at all times**: coherent content, correct dates, accurate statuses, zero markdown-lint errors
- `CHANGELOG.md` reflects shipped work; `BACKLOG.md` reflects planned work — no item should live in both

### Backlog cleanup

Periodically (at release or during housekeeping), move closed tickets that have been closed for **more than 3 days** from `BACKLOG.md` to `BACKLOG-archive.md`:

- Move table row(s) to the matching batch section in the archive (create section if needed)
- Move `### Detail` section too
- If the entire batch is done, move the whole block
- Tickets closed less than 3 days ago stay in `BACKLOG.md` for short-term visibility

### Estimation

#### What estimates represent

Estimates on each ticket represent the **AI implementation time** — how long the LLM agent takes to complete the work (coding, tests, quality checks), excluding time spent waiting for user input or approval.

Lot totals add **+15 min of human overhead** (testing, PR review, merge) on top of the sum of ticket estimates.

#### Producing an estimate

When creating a ticket, the LLM assigns a weighted estimate based on:

- Scope of code changes (files, modules, complexity)
- Test writing effort
- Integration risk
- Current **velocity ratio** (see below)

Formula: `displayed_estimate = raw_estimate × velocity_ratio`

If no velocity ratio has been computed yet, use `1.0` (no adjustment).

#### Tracking actuals

When starting work on a ticket, record `start_time` in the backlog detail. When completing a ticket, record `end_time`. Only count **active AI working time** — exclude any period where the agent is idle waiting for the user (interruptions, questions, approvals).

#### Velocity ratio

After each completed ticket, compute:

```
ticket_ratio = estimated_time / actual_time
```

The project's **velocity ratio** is the rolling average of all ticket ratios:

```
velocity_ratio = mean(all ticket_ratios)
```

Store the current `velocity_ratio` in the project's copilot-instructions or backlog metadata.

#### Revising estimates

When the velocity ratio is updated, **revise all pending (not yet started) ticket estimates**:

```
revised_estimate = raw_estimate × velocity_ratio
```

This ensures future estimates become more accurate over time. Already-completed tickets are not revised.

### Token consumption tracking

Track estimated token usage per ticket to understand cost and improve budgeting.

#### Measurement method

Use character-count heuristic: **~4 characters ≈ 1 token** (code/English). Slightly less for French prose (~3.5 chars/token).

For each turn `n` in a ticket, compute:

```
turn_cost_n = (context_history_n + tool_results_n + output_n) / 4
```

Where:

- `context_history_n` = cumulative size of all previous turns re-injected as input
- `tool_results_n` = total characters received from tool calls in this turn
- `output_n` = total characters produced by the LLM in this turn

Total ticket cost:

```
ticket_tokens ≈ Σ turn_cost_n (for all turns in the ticket)
```

> Note: cost is triangular — each turn includes the full prior history. Long conversations are exponentially more expensive than short ones.

#### What to record

In the backlog detail for each completed ticket, note:

- `turns`: number of LLM turns
- `estimated_tokens`: computed estimate (using formula above)

#### Using the data

- Compare token costs across ticket types to identify expensive patterns
- Factor token estimates into future ticket planning (alongside time estimates)
- A ticket that took few turns but many tokens → heavy reads (large files). A ticket with many turns but moderate tokens → iterative back-and-forth.

### Per-change steps

1. Make changes
2. Update tests
3. Run tests + check VS Code errors (mypy, ruff, Pylance)
4. Update `CHANGELOG.md`
5. **Bump the patch version** and reinstall the package (ensures tests run against the modified code, not a stale cache):
   ```powershell
   # location of version varies per project (pyproject.toml, constants.py, etc.)
   pip install -e . --quiet   # or equivalent
   ```

---

## Pull Requests

- PR titles and descriptions must be written in **English**
- **Before opening a PR**, push all commits on the feature branch
- **Never merge branches directly**. Always go through a PR.

---

## Versioning & Releases

### Semantic Versioning

Projects follow **SemVer** (`MAJOR.MINOR.PATCH`):

- **PATCH** (`x.y.Z`): bumped after each change (traceability — ensures tests run against modified code). The patch level is not meaningful for delivered versions.
- **MINOR** (`x.Y.0`): bumped at release for non-breaking changes (new features, improvements, bug fixes delivered together).
- **MAJOR** (`X.0.0`): bumped for breaking changes or major rewrites. **Always ask the user for confirmation** before bumping major.

### Release process

1. Analyse changes since last release (git log, CHANGELOG `[Unreleased]`)
2. Determine version bump: MINOR (default) or MAJOR (if breaking — confirm with user)
3. Create a `release/x.y.z` branch from `develop`
4. Bump version in the project's version file
5. Stamp `CHANGELOG.md`: replace `[Unreleased]` with `[x.y.z] — YYYY-MM-DD`
6. Update `ROADMAP.md`: move batch from planned → Completed
7. Open a PR `release/x.y.z` → `main`/`master`
8. After merge: **tag** with `git tag vx.y.z` and push the tag

---

## Notes System

- When user says **"note"** or **"note that"**, update the project's copilot-instructions.md file with the new instruction

---

## Environment

- Windows + PowerShell
- Activate venv: `.venv\Scripts\Activate.ps1` (or `.\venv\Scripts\Activate.ps1`)

---

## Context Compaction

Trigger a context compaction when context usage reaches 60%.

When compacting, apply the following rules:

- Keep all project rules, constraints, and conventions word-for-word — never paraphrase them.
- Retain the full current task description, subtask list, and progress status.
- Retain all file paths, module names, and architectural decisions.
- Aggressively summarise tool outputs, command results, and logs: one line per result unless a detail is directly relevant to the current task.
