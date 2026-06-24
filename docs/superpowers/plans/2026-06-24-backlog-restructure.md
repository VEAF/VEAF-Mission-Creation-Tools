# Backlog Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic `backlog.md`/`backlog-archive.md` with a per-lot `.backlog/` directory structure and wire the Matt Pocock engineering skills to it via per-repo config (no upstream fork).

**Architecture:** Active lots become rich directories (`.backlog/<LOT>/PRD.md` + `tickets/NN-slug.md`); completed lots become one compact file each under `.backlog/archive/<LOT>.md`. The Matt Pocock skills stay globally installed and unmodified; a per-repo config under `docs/agents/` plus an `## Agent skills` block in `CLAUDE.md` adapts them to this backlog. The index `.backlog/README.md` is agent-maintained (no generator script).

**Tech Stack:** Markdown only. No code, no new dependencies. Verification via `grep`, `ls`, `mkdocs build`, and a live `/to-prd` + `/to-issues` smoke test.

## Global Constraints

- **Git workflow:** all work on a single feature branch `chore/backlog-restructure` cut from `develop-v6`; one PR targeting `develop-v6` (CLAUDE.md §8). Never commit directly to `develop-v6`/`master`/`main`.
- **Sync first:** before starting, `git fetch` then `git pull --ff-only` on `develop-v6` (CLAUDE.md §8.0).
- **Commit style:** Conventional Commits in English (`type(scope): description`).
- **Artifact language:** all `.backlog/` content (PRD.md, tickets, index, archive) and all docs are written in **English**.
- **Status vocabulary (exact):** `ready` ⬜ · `in-progress` 🔄 · `waiting-human` 🧑 · `done` ✅ · `wontfix` 🚫.
- **Active-lot selection rule:** an "active lot" is any lot whose Summary-table status is **not** ✅. Currently: `FOOTHOLD-V6`, `CLEANUP-LUPA`, `Lot 5 — RELEASE` (plus any 🟡/🧑 lot found at execution time).
- **mkdocs:** `.backlog/` must stay out of the published site (dotfolder is ignored by mkdocs by default — do not add it to `mkdocs.yml` nav).
- **Spec:** `docs/superpowers/specs/2026-06-24-backlog-restructure-design.md` is the source of truth for format and decisions.

---

### Task 1: Branch + scaffold the structure and skill config

Wire the Matt Pocock skills *first*, so the new structure is the live convention before any content moves. This task delivers a working (empty) `.backlog/` and the config that makes `/to-prd`/`/to-issues` target it.

**Files:**
- Create: `.backlog/README.md`, `.backlog/archive/.gitkeep`
- Create: `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, `docs/agents/domain.md`
- Modify: `CLAUDE.md` (append `## Agent skills` block)

**Interfaces:**
- Produces: the `.backlog/` root and the `docs/agents/*` config that Tasks 2–4 and all future skill runs depend on.

- [ ] **Step 1: Sync and branch**

```bash
cd /c/dev/dpierron/vmct-v6
git fetch
git switch develop-v6 && git pull --ff-only
git switch -c chore/backlog-restructure
```

- [ ] **Step 2: Create the directory skeleton**

```bash
mkdir -p .backlog/archive
touch .backlog/archive/.gitkeep
```

- [ ] **Step 3: Write `docs/agents/issue-tracker.md`**

```markdown
# Issue tracker: local `.backlog/` directory

Lots, PRDs, and tickets for this repo live as markdown under `.backlog/`.

## Conventions

- One lot per directory: `.backlog/<LOT-ID>/`
- The PRD is `.backlog/<LOT-ID>/PRD.md` (Matt's PRD template; no separate `## Goal`)
- Tickets are `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`, numbered from `01` in dependency order
- Status is a `Status:` line near the top of each PRD/ticket file (see `triage-labels.md`)
- The lot index (Summary table of every lot + status) is `.backlog/README.md`, maintained by hand
- Completed lots are moved to `.backlog/archive/<LOT-ID>.md` (compact, ticket table preserved) once closed > 3 days

## When a skill says "publish to the issue tracker"

- A PRD → write `.backlog/<LOT-ID>/PRD.md`, create the directory if needed, and add a row to `.backlog/README.md`.
- An issue → write `.backlog/<LOT-ID>/tickets/<NN>-<slug>.md`.
- New artifacts are created at `Status: ⬜ ready`.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user normally passes the lot ID or ticket path directly.
```

- [ ] **Step 4: Write `docs/agents/triage-labels.md`**

```markdown
# Triage labels → local Status vocabulary

This repo uses a single `Status:` line (one value at a time). Matt's five triage
roles map onto it as follows:

| Status        | Emoji | Matt triage role(s)            |
|---------------|-------|--------------------------------|
| ready         | ⬜    | ready-for-agent                |
| waiting-human | 🧑    | ready-for-human, needs-info    |
| wontfix       | 🚫    | wontfix                        |

Lifecycle-only states (no triage-role equivalent): `in-progress` 🔄, `done` ✅.

`needs-triage` is not used — lots are created already specified, not triaged from
raw external reports. `/to-prd` and `/to-issues` create artifacts at `ready` ⬜.
```

- [ ] **Step 5: Write `docs/agents/domain.md`**

```markdown
# Domain docs

Single-context repo.

- Domain language / glossary: `CONTEXT.md` at the repo root.
- Architectural decisions: `docs/adr/`.

Skills that read domain context (`improve-codebase-architecture`, `diagnosing-bugs`,
`tdd`) should read `CONTEXT.md` and consult `docs/adr/` for prior decisions in the
area being changed.
```

- [ ] **Step 6: Append the `## Agent skills` block to `CLAUDE.md`**

Append this section to the end of `CLAUDE.md`:

```markdown
## Agent skills

### Issue tracker

Lots/PRDs/tickets live as markdown under `.backlog/<LOT-ID>/` (active) and
`.backlog/archive/<LOT-ID>.md` (completed). See `docs/agents/issue-tracker.md`.

### Triage labels

Single `Status:` vocabulary (⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix),
mapped to Matt's triage roles. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
```

- [ ] **Step 7: Seed the index `.backlog/README.md`**

```markdown
# Backlog — VEAF Mission Creation Tools v6

Per-lot backlog. Active lots are directories under `.backlog/<LOT-ID>/`; completed
lots are compacted into `.backlog/archive/<LOT-ID>.md`. Sequencing lives in
[ROADMAP](../ROADMAP.md); this index is the source of truth for **scope and status**.

## Legend

- **Status**: ⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix

## Active lots

| Lot | Status |
|-----|--------|
| _populated in Task 2_ | |

## Archived lots

See [`archive/`](archive/). Index rows are added here as lots are archived.
```

- [ ] **Step 8: Verify the structure exists**

Run: `ls -R .backlog docs/agents`
Expected: `.backlog/README.md`, `.backlog/archive/.gitkeep`, and the three `docs/agents/*.md` files are listed.

- [ ] **Step 9: Commit**

```bash
git add .backlog docs/agents CLAUDE.md
git commit -m "chore(backlog): scaffold .backlog structure and wire Matt Pocock skills config"
```

---

### Task 2: Migrate active lots to rich directories

Convert each active lot (selection rule in Global Constraints) into a directory
with a `PRD.md` and one file per ticket. `CLEANUP-LUPA` is worked fully below as
the pattern; apply the same transformation to `FOOTHOLD-V6` and `Lot 5 — RELEASE`
(and any 🟡/🧑 lot), reading their blocks from `backlog.md`.

**Files:**
- Create: `.backlog/CLEANUP-LUPA/PRD.md`, `.backlog/CLEANUP-LUPA/tickets/01-drop-lupa-dependency.md`
- Create: `.backlog/FOOTHOLD-V6/PRD.md`, `.backlog/FOOTHOLD-V6/tickets/01..09-*.md`
- Create: `.backlog/RELEASE/PRD.md` (+ tickets if any) for "Lot 5 — RELEASE"
- Modify: `.backlog/README.md` (fill the Active lots table)

**Interfaces:**
- Consumes: the `.backlog/` root + config from Task 1.
- Produces: the rich active-lot directories that the smoke test (Task 7) reads.

**Transformation rule (apply per active lot):**
1. `## Lot <ID> — <title>` block in `backlog.md` → `.backlog/<ID>/PRD.md`.
2. The `**Goal**` paragraph → `## Problem Statement` + `## Solution` (split the
   "what's wrong" from the "what we'll do"). No `## Goal` heading.
3. `**Branch**` line → a `Branch:` line near the top.
4. Each row of the ticket table → `.backlog/<ID>/tickets/<NN>-<slug>.md` using the
   ticket template; `<NN>` = the numeric suffix of the ticket ID, `<slug>` = a short
   kebab-case name; the row's `Files`/`Type`/`Status` become front-matter lines;
   the row's description → `## What to build`; acceptance criteria → checklist
   (derive from the description if the table had none); `Blocked by` from any
   dependency noted in the description, else "None — can start immediately".

- [ ] **Step 1: Write `.backlog/CLEANUP-LUPA/PRD.md`**

```bash
mkdir -p .backlog/CLEANUP-LUPA/tickets
```

```markdown
# Lot CLEANUP-LUPA — remove the dead `lupa` dependency

Status: ⬜ ready
Branch: chore/cleanup-lupa → PR → develop-v6

## Problem Statement

`lupa` (a Lua runtime) is no longer imported anywhere in `src/python/`: SECREV-001
routed all `.miz`/Lua parsing through the pure-Python `luadata` state machine to
remove the RCE, and RC-002 then made `lupa` a non-optional dependency and a
`hiddenimports` entry in the `.spec` to bundle it into the exe. It is now pure dead
weight in the dependency tree and the binary.

## Solution

Remove `lupa` from the dependency tree, the PyInstaller spec, and the mypy
overrides; confirm nothing imports it and the exe still builds.

## User Stories

1. As a maintainer, I want the dependency tree free of unused packages, so that the
   build is smaller and the supply-chain surface is minimal.

## Implementation Decisions

- Drop `lupa` from `pyproject.toml` dependencies.
- Drop the `lupa` `hiddenimports` entry from `veaf-tools.spec`.
- Drop the `lupa.*` mypy override.

## Testing Decisions

- Static check: `grep -r "import lupa" src/` returns nothing.
- Build check: the PyInstaller exe still builds.

## Out of Scope

- Reintroducing any Lua-execution path (deliberately avoided per SECREV-001).
```

- [ ] **Step 2: Write `.backlog/CLEANUP-LUPA/tickets/01-drop-lupa-dependency.md`**

```markdown
# CLEANUP-LUPA-001 — drop the dead `lupa` dependency

Status: ⬜ ready
Type: chore
Files: `pyproject.toml`, `veaf-tools.spec`

## What to build

Remove `lupa` from `pyproject.toml` dependencies, the `hiddenimports` list in
`veaf-tools.spec`, and the `lupa.*` mypy override. Verify no `import lupa` remains
and the exe still builds.

## Acceptance criteria

- [ ] `lupa` removed from `pyproject.toml` dependencies
- [ ] `lupa` removed from `hiddenimports` in `veaf-tools.spec`
- [ ] `lupa.*` mypy override removed
- [ ] `grep -r "import lupa" src/` returns nothing
- [ ] `poetry install` succeeds and the exe still builds

## Blocked by

None — can start immediately
```

- [ ] **Step 3: Migrate `FOOTHOLD-V6`**

Read the `## Lot FOOTHOLD-V6` block in `backlog.md` (the Goal/Branch paragraph and
its 9-row ticket table: FOOTHOLD-V6-001 … 009). Apply the transformation rule:
write `.backlog/FOOTHOLD-V6/PRD.md` and `tickets/01-…` through `tickets/09-…`,
preserving each ticket's existing `Status` emoji (e.g. 007 stays `🧑 waiting-human`).

- [ ] **Step 4: Migrate `Lot 5 — RELEASE`**

Read the `## Lot 5 — RELEASE` block in `backlog.md`. Write `.backlog/RELEASE/PRD.md`
(and any ticket files if the block lists tickets). Use a directory name without
spaces (`RELEASE`).

- [ ] **Step 5: Catch any remaining 🟡/🧑 lots**

Run: `grep -nE "^\| Lot " backlog.md | grep -E "🟡|🧑"`
For each lot returned that is not already migrated, apply the transformation rule.
Expected at execution: confirm the full active set is covered.

- [ ] **Step 6: Fill the Active lots table in `.backlog/README.md`**

Replace the placeholder row with one row per migrated active lot, e.g.:

```markdown
| Lot | Status |
|-----|--------|
| [FOOTHOLD-V6](FOOTHOLD-V6/PRD.md) — adopt the third-party Foothold mission onto the v6 toolchain | ⬜ |
| [CLEANUP-LUPA](CLEANUP-LUPA/PRD.md) — remove the dead `lupa` dependency | ⬜ |
| [RELEASE](RELEASE/PRD.md) — release | ⬜ |
```

- [ ] **Step 7: Verify active lots**

Run: `ls -R .backlog/CLEANUP-LUPA .backlog/FOOTHOLD-V6 .backlog/RELEASE`
Expected: each has a `PRD.md`; FOOTHOLD-V6 has `tickets/01..09`.

- [ ] **Step 8: Commit**

```bash
git add .backlog
git commit -m "docs(backlog): migrate active lots to per-lot directories"
```

---

### Task 3: Bulk-convert completed lots to compact archive files

Each completed (`✅`) lot block in `backlog.md` and `backlog-archive.md` becomes one
compact file `.backlog/archive/<LOT-ID>.md`. Tickets are **not** split — the ticket
table is preserved as-is. This is mechanical and high-volume (~137 lot blocks).

**Files:**
- Create: `.backlog/archive/<LOT-ID>.md` (one per completed lot)
- Modify: `.backlog/README.md` (Archived lots note)

**Interfaces:**
- Consumes: `.backlog/archive/` from Task 1.
- Produces: the archive that ADR/CHANGELOG cross-references (rewired in Task 5) point into.

**Transformation rule (apply per completed lot block):**
- `## Lot <ID> — <title>` heading → `# Lot <ID> — <title>` as the archive file's H1.
- Keep the `**Goal**`, `**Branch**`, and the full ticket table verbatim.
- Add a `Status: ✅ done` line under the H1.
- Filename: `<LOT-ID>.md` (the ID from the heading; replace spaces, e.g.
  `Phase 0b — GitHub cleanup` → `PHASE-0B.md`).

- [ ] **Step 1: List every completed lot heading (the work-list)**

Run:
```bash
grep -nE "^## (Lot|Phase) " backlog.md backlog-archive.md
```
Expected: ~137 headings. This is the exhaustive list to convert (every one except
the active lots already migrated in Task 2).

- [ ] **Step 2: Worked example — convert one lot**

For `## Lot WEATHERMARK-REMOVE — retire the WeatherMark community script everywhere`
in `backlog.md`, create `.backlog/archive/WEATHERMARK-REMOVE.md`:

```markdown
# Lot WEATHERMARK-REMOVE — retire the WeatherMark community script everywhere

Status: ✅ done

<the original **Goal**, **Branch**, and ticket table, verbatim>
```

- [ ] **Step 3: Convert all remaining completed lots**

Apply Step 2's rule to every heading from Step 1 (excluding the active lots from
Task 2). Process in batches; for each, the archive file is a verbatim copy of the
lot block with the adjusted H1 and the `Status: ✅ done` line.

- [ ] **Step 4: Cross-check counts**

Run:
```bash
ls .backlog/archive/*.md | wc -l
grep -cE "^## (Lot|Phase) " backlog.md backlog-archive.md
```
Expected: the archive `.md` count equals the total completed-lot heading count
(total headings minus the active lots migrated in Task 2). Reconcile any mismatch
before continuing.

- [ ] **Step 5: Note the archive in the index**

In `.backlog/README.md`, under "Archived lots", confirm the pointer to `archive/`
is present (no per-lot rows required for archived lots).

- [ ] **Step 6: Commit**

```bash
git add .backlog/archive .backlog/README.md
git commit -m "docs(backlog): archive completed lots as compact per-lot files"
```

---

### Task 4: Rewire references across the repo

Update every place that points at `backlog.md`/`BACKLOG.md` to the new structure.

**Files:**
- Modify: `CLAUDE.md` (§6 and §8.2), `.github/copilot-instructions-generic.md`, `ROADMAP.md`, `doc/ROADMAP.en.md`, `docs/adr/0005-spawn-data-externalization.md`, `docs/adr/0006-lua-runtime-i18n.md`

**Interfaces:**
- Consumes: the migrated `.backlog/` from Tasks 2–3.

- [ ] **Step 1: Find every reference**

Run:
```bash
grep -rniE "backlog(-archive)?\.md" --include='*.md' . | grep -v "^\./\.backlog/\|/site/\|/\.claude/worktrees/"
```
Expected: hits in `CLAUDE.md`, `.github/copilot-instructions-generic.md`,
`ROADMAP.md`, `doc/ROADMAP.en.md`, `docs/adr/0005…`, `docs/adr/0006…`.

- [ ] **Step 2: Update `CLAUDE.md` §6 (Backlog and Roadmap Maintenance)**

Replace the two bullets with:

```markdown
- **Real-Time Updates**: the `.backlog/` directory and `ROADMAP.md` must exactly reflect task status. Each active lot is a directory `.backlog/<LOT-ID>/` (PRD.md + tickets); `.backlog/README.md` is the lot index, maintained by hand.
- **Archiving**: move lots closed for more than 3 days from `.backlog/<LOT-ID>/` to a compact `.backlog/archive/<LOT-ID>.md`.
```

- [ ] **Step 3: Update `CLAUDE.md` §8.2 (Default Action Workflow)**

Replace step 2 with:

```markdown
2. **Create a lot** under `.backlog/<LOT-ID>/`: write `PRD.md` (Status `⬜ ready`) and one `tickets/<NN>-<slug>.md` per ticket. Add a row to `.backlog/README.md`.
```

- [ ] **Step 4: Update `.github/copilot-instructions-generic.md`**

Apply the same two-bullet replacement as Step 2.

- [ ] **Step 5: Update the ROADMAP link (both languages)**

In `ROADMAP.md` and `doc/ROADMAP.en.md`, change `[backlog.md](backlog.md)` to
`[.backlog/README.md](.backlog/README.md)`. Leave the sequencing content and the
"source of truth for scope and status" wording (now pointing at `.backlog/`).

- [ ] **Step 6: Update ADR cross-references**

In `docs/adr/0005-spawn-data-externalization.md` and `0006-lua-runtime-i18n.md`,
change "the X lot in `backlog.md`" to point at the archived file, e.g.
"the SPAWN-EXTERNALIZE lot in `.backlog/archive/TODO0609-SPAWN-EXTERNALIZE.md`"
(use the actual archived filename produced in Task 3).

- [ ] **Step 7: Verify no stale references remain**

Run:
```bash
grep -rniE "in (the )?backlog\.md|\(backlog\.md\)|BACKLOG\.md" --include='*.md' . | grep -v "/site/\|/\.claude/worktrees/\|/specs/\|/plans/"
```
Expected: no hits (the spec/plan files under `docs/superpowers/` may legitimately
mention the old name historically and are excluded).

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md .github/copilot-instructions-generic.md ROADMAP.md doc/ROADMAP.en.md docs/adr/0005-spawn-data-externalization.md docs/adr/0006-lua-runtime-i18n.md
git commit -m "docs: repoint backlog references to .backlog/ structure"
```

---

### Task 5: Record the decision as ADR 0009

**Files:**
- Create: `docs/adr/0009-backlog-restructure.md`

- [ ] **Step 1: Write the ADR**

Follow the format of an existing ADR (e.g. `docs/adr/0008-*`). Content:

```markdown
# 9. Backlog restructure to `.backlog/` per-lot directories

Date: 2026-06-24

## Status

Accepted

## Context

The backlog lived in a single ~161 KB `backlog.md` (+ ~138 KB archive). With one
branch/PR per lot, the monolith was a recurring merge-conflict surface, and loading
it cost significant agent context. We also wanted to drive the backlog with the
Matt Pocock engineering skills, which are issue-tracker-agnostic and configured per
repo (no fork required).

## Decision

Adopt a per-lot `.backlog/` structure: active lots are directories
(`.backlog/<LOT-ID>/PRD.md` + `tickets/<NN>-<slug>.md`), completed lots are compact
`.backlog/archive/<LOT-ID>.md` files. A single `Status:` vocabulary
(⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix) maps onto Matt's
triage roles. The Matt Pocock skills are configured via `docs/agents/*` and a
`## Agent skills` block in `CLAUDE.md`. The lot index `.backlog/README.md` is
maintained by hand. ROADMAP remains the sequencing source of truth.

## Consequences

- No more backlog merge conflicts; agents load only the relevant lot.
- `to-prd`/`to-issues` work against the local backlog with no upstream fork.
- One-time migration cost; archived shipped lots are kept compact, not split.
- See the design spec: `docs/superpowers/specs/2026-06-24-backlog-restructure-design.md`.
```

- [ ] **Step 2: Verify ADR numbering**

Run: `ls docs/adr/`
Expected: `0009-backlog-restructure.md` is the next number after the current highest.

- [ ] **Step 3: Commit**

```bash
git add docs/adr/0009-backlog-restructure.md
git commit -m "docs(adr): record backlog restructure decision (ADR 0009)"
```

---

### Task 6: Remove the old monolith

**Files:**
- Delete: `backlog.md`, `backlog-archive.md`

- [ ] **Step 1: Confirm everything is migrated**

Run:
```bash
grep -cE "^## (Lot|Phase) " backlog.md backlog-archive.md
ls .backlog/*/PRD.md .backlog/archive/*.md | wc -l
```
Expected: the migrated count (active PRDs + archive files) accounts for every lot
heading. Do not proceed if anything is unaccounted for.

- [ ] **Step 2: Delete the old files**

```bash
git rm backlog.md backlog-archive.md
```

- [ ] **Step 3: Final stale-reference sweep**

Run:
```bash
grep -rniE "backlog(-archive)?\.md" --include='*.md' . | grep -v "/\.backlog/\|/site/\|/\.claude/worktrees/\|/docs/superpowers/"
```
Expected: no hits.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(backlog): remove monolithic backlog.md and backlog-archive.md"
```

---

### Task 7: Verify the skills drive the new backlog, then open the PR

**Files:** none (verification + PR).

- [ ] **Step 1: mkdocs still builds, `.backlog/` excluded**

Run: `poetry run mkdocs build --strict`
Expected: build succeeds; no warning about `.backlog/` pages (dotfolder is ignored).
If `--strict` fails on an unrelated pre-existing warning, re-run without `--strict`
and confirm no new warning mentions `.backlog` or a broken backlog link.

- [ ] **Step 2: Smoke-test `/to-prd`**

In a Claude Code session in this repo, hold a short feature conversation, then run
`/to-prd`. Confirm it writes `.backlog/<NEW-LOT>/PRD.md` in the agreed format
(Status `⬜ ready`, Problem Statement + Solution, no `## Goal`) and adds an index row.

- [ ] **Step 3: Smoke-test `/to-issues`**

Run `/to-issues` against that PRD. Confirm it writes
`.backlog/<NEW-LOT>/tickets/01-*.md` (and further numbered tickets) using the ticket
template, at `Status: ⬜ ready`, in dependency order.

- [ ] **Step 4: Clean up the smoke-test lot**

```bash
rm -rf .backlog/<NEW-LOT>
# revert the smoke-test index row in .backlog/README.md
git checkout .backlog/README.md
```

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin chore/backlog-restructure
gh pr create --base develop-v6 --title "chore: restructure backlog into .backlog/ + wire Matt Pocock skills" --body "Implements docs/superpowers/specs/2026-06-24-backlog-restructure-design.md (ADR 0009). Replaces monolithic backlog.md with per-lot .backlog/ directories and configures the Matt Pocock engineering skills via docs/agents/*."
```

- [ ] **Step 6: Monitor the PR**

Wait for Sourcery review and CI (CLAUDE.md §8.11). Address feedback; merge when
approved. Do **not** request a Copilot review (CLAUDE.md §10).

---

## Self-Review

**Spec coverage:**
- §1 Target structure → Task 1 (skeleton) + Tasks 2–3 (content). ✓
- §2 File formats → Task 2 worked examples (PRD.md, ticket). ✓
- §3 Status model → `docs/agents/triage-labels.md` (Task 1.4); statuses used throughout. ✓
- §4 Index & archiving → Task 1.7 (index), Task 3 (archive), Task 4.2 (3-day rule in CLAUDE.md). ✓
- §5 Skills wiring → Task 1.3–1.6. ✓
- §6 Rewiring references → Task 4. ✓
- §7 Migration plan → Tasks 2 (active), 3 (completed), 6 (delete), 7 (verify). ✓
- ADR 0009 → Task 5. ✓

**Placeholder scan:** The only literal `_populated in Task 2_` token is an
intentional index placeholder that Task 2 Step 6 replaces; the angle-bracket
`<...>` tokens in Tasks 2–3 are per-lot substitution slots for a mechanical
transformation whose rule is given in full — not unspecified work.

**Consistency:** Status vocabulary (`ready`/`in-progress`/`waiting-human`/`done`/
`wontfix` + emoji) is identical in the spec, the config file, ADR 0009, and every
task. Directory/file naming (`.backlog/<LOT-ID>/PRD.md`, `tickets/<NN>-<slug>.md`,
`archive/<LOT-ID>.md`) is consistent across tasks.
