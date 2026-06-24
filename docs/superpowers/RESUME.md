# Resume note — backlog restructure

**Branch:** `chore/backlog-restructure`
**Paused:** 2026-06-24
**State:** planning done, **migration not started** (clean stopping point).

## What exists

- Design spec: [`specs/2026-06-24-backlog-restructure-design.md`](specs/2026-06-24-backlog-restructure-design.md)
- Implementation plan (7 tasks): [`plans/2026-06-24-backlog-restructure.md`](plans/2026-06-24-backlog-restructure.md)

Both are committed on this branch. No `.backlog/` directory or migration changes
exist yet — Task 1 creates them.

## Goal in one line

Replace the monolithic `backlog.md` / `backlog-archive.md` with a per-lot
`.backlog/` structure (active lots = directories with `PRD.md` + `tickets/NN.md`;
completed lots = compact `.backlog/archive/<LOT>.md`), and wire the Matt Pocock
engineering skills to it via `docs/agents/*` config — **no upstream fork**.

## How to resume

1. `git fetch origin && git switch chore/backlog-restructure`
2. In Claude Code, in this repo:
   > Reprends l'exécution du plan `docs/superpowers/plans/2026-06-24-backlog-restructure.md`
   > à partir de la Tâche 1. La branche existe déjà (saute la création de branche au step 1).
3. Recommended: use `superpowers:executing-plans` or `superpowers:subagent-driven-development`.

## Gotchas

- **Skills are not in git.** Matt Pocock's skills are installed globally on the
  original machine (`~/.claude/skills/`). They are only needed for **Task 7**
  (smoke-test of `/to-prd` + `/to-issues`). Tasks 1–6 are pure file operations.
  If missing here: `npx skills add mattpocock/skills -y` (local, no `-g` —
  PromptScript skills reject global install).
- **Open decision (not yet answered):** whether to script Task 3 (bulk-convert
  ~137 completed lots by parsing `## Lot` blocks) instead of doing it by hand.
  Decide before starting Task 3.

## Decisions locked during brainstorming

- Big-bang migration (clean end state).
- Layout A "Matt-native": one directory per lot, one file per ticket.
- Active lots → rich directories; completed lots → compact archive files.
- Status vocabulary: `ready` ⬜ · `in-progress` 🔄 · `waiting-human` 🧑 · `done` ✅ · `wontfix` 🚫.
- Index `.backlog/README.md` maintained by hand (no generator script).
- Artifacts written in English.
