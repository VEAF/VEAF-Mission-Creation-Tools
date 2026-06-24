# Design — Backlog restructure to `.backlog/` + Matt Pocock skills wiring

**Date:** 2026-06-24
**Status:** Design approved, pending implementation plan
**Decision record:** to be captured as `docs/adr/0009-backlog-restructure.md` during implementation

---

## Problem

The project tracks all work in a single monolithic `backlog.md` (~161 KB) plus
`backlog-archive.md` (~138 KB), organised as **Lots** (epics), each with a `Goal`,
a `Branch`, and a table of tickets (`# | Ticket | Files | Type | Status`). This
format has two structural problems:

1. **Merge conflicts.** The workflow uses one branch + one PR per lot
   (CLAUDE.md §8.3). Every branch that updates the backlog edits the same giant
   file, so the backlog is a recurring merge-conflict surface.
2. **Agent context cost.** The whole 161 KB file is loaded whenever an agent
   reasons about "what's left to do" — expensive and attention-diluting, which
   directly undercuts the AFK-agent workflows the Matt Pocock engineering skills
   (`to-prd`, `to-issues`, `triage`, `qa`) are meant to enable.

Separately, we want the Matt Pocock engineering skills to drive this backlog.
Those skills are **issue-tracker-agnostic**: they read a per-repo config file
(`docs/agents/issue-tracker.md`, written by `setup-matt-pocock-skills`) that
describes *how* to "publish to the issue tracker". No fork of `mattpocock/skills`
is required — only configuration.

## Goals

- Replace the monolith with a **per-lot directory structure** so each lot is an
  isolated unit (no shared-file conflicts; agents load only the relevant lot).
- Wire the Matt Pocock skills to this structure via per-repo config, **without
  forking** the upstream skills repo.
- Preserve what the monolith gave for free: a scannable overview (Summary table)
  and the ROADMAP sequencing relationship.
- Keep the project's existing status vocabulary; extend it only as far as needed
  to map onto the skills' triage roles.

## Non-goals

- Forking or editing the upstream skill files. Backend choice is configuration.
- Building backlog tooling/automation (index is agent-maintained — see §5).
- Reworking ROADMAP's purpose: it remains the **sequencing** source of truth;
  `.backlog/` becomes the **scope + status** source of truth.

---

## 1. Target structure

```
.backlog/
  README.md                      # agent-maintained index: the Summary table (all lots + status)
  <LOT-ID>/                      # one directory per ACTIVE lot
    PRD.md                       # Goal, Branch, Problem/Solution, Implementation/Testing Decisions
    tickets/
      01-<slug>.md               # one rich ticket per file
      02-<slug>.md
  archive/
    <LOT-ID>.md                  # COMPLETED lots: one compact .md per lot (tickets kept as a table)
```

- `.backlog/` is a dotfolder → ignored by mkdocs (correct: it is internal working
  state, not published documentation). `backlog.md` is *not* in the mkdocs nav
  today; only `ROADMAP.md` is.
- `backlog.md` and `backlog-archive.md` are **removed** at the end of the migration.

## 2. File formats

### `PRD.md` (output of `/to-prd`)

The current per-lot block, enriched with Matt's PRD template:

```markdown
# Lot <LOT-ID> — <title>

Status: ⬜ ready
Branch: feature/<id>  (or fix/<id>) → PR → develop-v6

## Problem Statement
## Solution
## User Stories
## Implementation Decisions
## Testing Decisions
## Out of Scope
## Further Notes
```

- The `Goal` paragraph from the old format maps to **Problem Statement +
  Solution**; there is **no separate `## Goal` heading** — the template replaces it.
- `Status:` here is the **lot-level** headline status (see §3).
- **Language:** all generated artifacts (`PRD.md`, `tickets/*.md`, the index) are
  written in **English**, matching the existing lots, CLAUDE.md, ADRs, and commit
  conventions.

### `tickets/NN-slug.md` (output of `/to-issues`)

Matt's issue template plus the project's existing columns as light front-matter:

```markdown
# <LOT-ID>-NNN — <title>

Status: ⬜ ready
Type: feat | fix | chore
Files: `path/a`, `path/b`

## What to build
## Acceptance criteria
- [ ] ...
## Blocked by
- <LOT-ID>-0NN   (or "None — can start immediately")
```

- Tickets are numbered from `01`, in dependency order (blockers first), matching
  Matt's `to-issues` process.
- Richer than today's one-line table rows — this is an intentional improvement
  for AFK-agent consumption.

## 3. Status model

A single `Status:` vocabulary (a ticket/lot has exactly one state at a time).
Five values; the project's existing emoji absorb two of Matt's five triage roles.

| `Status:`       | Emoji | Matt triage role absorbed      | Meaning                                   |
|-----------------|-------|--------------------------------|-------------------------------------------|
| `ready`         | ⬜    | `ready-for-agent`              | specified, AFK-ready (the old "to do")    |
| `in-progress`   | 🔄    | —                              | being worked (absorbs the old `partial` 🟡)|
| `waiting-human` | 🧑    | `ready-for-human` + `needs-info` | David gate / waiting on information      |
| `done`          | ✅    | —                              | complete → archive after 3 days           |
| `wontfix`       | 🚫    | `wontfix`                      | abandoned → archive                       |

Dropped from the first draft (not needed for this project's workflow, which has
no formal external-issue intake): `needs-triage` (🔍) — lots are born specified;
`needs-info` (❓) — folded into `waiting-human`; `partial` (🟡) — folded into
`in-progress`.

- `/to-prd` and `/to-issues` create artifacts at `⬜ ready`.
- The full five Matt roles remain **mappable**, so `/triage` and `/qa` still work
  if adopted later; day-to-day only the four/five emoji above are used.
- **Lot-level status** lives in `PRD.md`'s `Status:` line, set editorially (as the
  Summary row is set today). It is not a computed rollup, to avoid a second source
  of truth.

## 4. Index & archiving

- **Index** — `.backlog/README.md` holds the Summary table (one row per lot:
  ID, title, status). **Agent-maintained**: the agent updates it when creating or
  closing a lot, exactly as the current Summary table is maintained. No generator
  script (explicitly out of scope).
- **Archiving** — the existing 3-day rule (CLAUDE.md §6) is preserved: a lot
  closed for >3 days is moved from `.backlog/<LOT>/` to a compacted
  `.backlog/archive/<LOT>.md` (tickets collapsed back into a single table — no
  need to keep per-ticket files for shipped work).

## 5. Matt Pocock skills wiring (per-repo config)

Run `/setup-matt-pocock-skills` choosing **"Other"** (the built-in "Local
markdown" mode assumes `.scratch/<feature>/`, which differs from this layout), to
write:

- `docs/agents/issue-tracker.md` — describes the `.backlog/<lot>/` convention
  above: where lots live, that `/to-prd` writes `PRD.md`, that `/to-issues` writes
  `tickets/NN-slug.md`, how to "fetch a ticket" (read the file by path/ID), and
  the archive rule.
- `docs/agents/triage-labels.md` — the §3 mapping (the five Matt roles → this
  project's `Status:` values/emoji).
- `docs/agents/domain.md` — single-context: `CONTEXT.md` + `docs/adr/`.
- An `## Agent skills` block added to `CLAUDE.md` pointing at the three files
  above (this is what keeps the skills aware of the config at runtime).

The skills themselves are installed **globally** (`~/.claude/skills/`) and are
**not modified**; this per-repo config is what adapts them to the markdown backlog.

## 6. Rewiring existing references

- `CLAUDE.md` §6 and §8.2 ("Create a lot in BACKLOG.md") → "create a
  `.backlog/<id>/` directory".
- `.github/copilot-instructions-generic.md` — same backlog rules.
- `ROADMAP.md` — the `[backlog.md](backlog.md)` link → `.backlog/README.md`
  (sequencing content unchanged; lots still referenced by ID).
- ADRs `0005`, `0006` — "see the X lot in backlog.md" → `.backlog/...` (active) or
  `.backlog/archive/...`.
- New `docs/adr/0009-backlog-restructure.md` — records this decision (consistent
  with the project's ADR culture).

## 7. Migration plan (big-bang, but selective)

1. Create `.backlog/` and `.backlog/archive/`.
2. **Active lots** (~4: `FOOTHOLD-V6`, `CLEANUP-LUPA`, `Lot 5 RELEASE`, plus any
   🟡/🧑 such as `TODO0609-TRIGGERS-VERIFY`, `BUILD-COMMUNITY-SOUNDS`) → rich
   directories (`PRD.md` + split `tickets/NN.md`).
3. **Completed lots** (from both `backlog.md` and `backlog-archive.md`) →
   `.backlog/archive/<LOT>.md`, one compact file per lot (ticket table preserved,
   not split).
4. Write `.backlog/README.md` (the Summary table).
5. Rewiring of §6 + new ADR 0009.
6. Write the `docs/agents/*` config (via `/setup-matt-pocock-skills`, mode Other).
7. Delete `backlog.md` and `backlog-archive.md`.
8. **Verification** — run `/to-prd` then `/to-issues` on a real conversation and
   confirm a correctly-formatted `.backlog/<lot>/` directory with tickets is
   produced; spot-check that `⬜/🧑` map to the intended Matt roles.

## Open questions / risks

- **Git workflow for the migration itself.** This restructure is itself "a lot"
  and should follow CLAUDE.md §8 (feature branch → PR → `develop-v6`), not a
  direct commit. The implementation plan should sync first (§8.0) and run on a
  dedicated branch (e.g. `chore/backlog-restructure`).
- **Lot-ID collisions.** A few Matt skills share short names across categories;
  not relevant here, but lot directory names must stay unique (they already are,
  by the `<AREA>-<n>` convention).
- **Mechanical bulk-conversion of ~80 completed lots** is the bulk of the effort;
  it is pure text reshaping (table rows → compact archive files) and is low-risk
  but tedious — a good candidate for batching.
