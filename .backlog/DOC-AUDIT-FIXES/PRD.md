# DOC-AUDIT-FIXES — the 2026-08-13 documentation audit, acted on

Status: 🔄 in-progress

Origin: a five-pass parallel audit of `doc/` (2026-08-13): FR/EN structural parity, Lua script
pages vs `src/scripts/veaf/`, CLI/YAML references vs the Python code, prose proofreading, and a
gap hunt against the CHANGELOG. ~150 distinct defects. The surgical lists live **in the tickets**,
because the audit session's context is the only other place they exist.

## What the audit established

The `docs-check` gate keeps links, anchors, nav and translation *existence* healthy — none of that
was broken. What rotted is everything the gate cannot see: **content**. Three families:

1. **Active lies** — pages stating the opposite of the code. The worst cluster is security: the
   pilot guide still promises the 10-minute session `REVIEW-SECURITY-LAYER` deleted, and 11
   references to `/secu login` survive across the script pages. Others: `veafSanctuary` documents
   its `coalition` field **inverted**, `veafAirWaves` misdescribes its altitude gates, every
   command example on `veafInterpreter.md` **aborts** when typed (unknown keys are fatal since the
   parser refactor), and `MISSION_YAML_REFERENCE` says security is off by default when the runtime
   default is on.
2. **Broken form** — a rendering defect repeated ~40× in `LUA_API_REFERENCE`, a reference table
   whose "Aircraft" column holds engine types on 72 of 88 rows, 5 dead anchors the gate
   structurally cannot catch, 4 links that escape `docs_dir`, ~50 typos/franglais items.
3. **Holes** — the new security model has no pilot-facing page, checklists are invisible from the
   pilot docs, `kneeboard_only` and `--parking` are documented nowhere, and the CLI has no real
   reference (David's call: full command documentation is wanted **in addition to** `--help`).

## David's arbitrations (2026-08-13)

- **a** — tier names: **fix the code**, not the doc. The dispatchers still only accept `L0/L1/L9/MM`;
  the decided model (new names canonical, old ones deprecated aliases) is what the doc already
  describes. → `FIX-DOCAUDIT-CODE`.
- **b** — `doc/ROADMAP.md` becomes a **thin pointer** to the root `ROADMAP.md` (both languages).
  Rewriting it as a copy recreates the drift just measured.
- **c** — **write the full CLI reference**: all 25 `veaf-tools` commands with their options. Doc in
  addition to `--help`, his words. Ticket 04.
- **d** — the five undocumented Lua modules get **their own lot** (`DOC-MODULE-PAGES`), not a line
  here.
- **e** — purge the "this page used to say the wrong thing until <date>" self-narration from
  reference pages; provenance lives in git and the CHANGELOG.
- **f** — normalise the AI catalogue's per-language anchors to the repo convention (identical
  English slugs in both languages).

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Active lies — security cluster + factual inversions](tickets/01-active-lies.md) | ✅ |
| 02 | [Broken form — rendering, dead anchors, prose](tickets/02-broken-form.md) | ✅ |
| 03 | [Holes and structure — new sections, ROADMAP pointer, anchors](tickets/03-holes-and-structure.md) | ⬜ |
| 04 | [The full CLI reference — 25 commands, options included](tickets/04-cli-reference.md) | ⬜ |

Delivery: **two PRs** — 01+02 (corrections), then 03+04 (new content) — so each review is one kind
of reading.

## Out of scope

- The code bugs the audit surfaced (tier-name dispatchers, `_transport` markId, the fog constant,
  `cli.py`'s stale help, the two `docs-check` blind spots) → `FIX-DOCAUDIT-CODE`.
- Pages for the five undocumented modules → `DOC-MODULE-PAGES`.

## Definition of Done

- `poetry run docs-check` green; the backlog gate green.
- Every fix lands in **both languages in the same commit** — a fix in one language is itself a
  defect (three were found).
- No new hand-written shipped version anywhere (the deploy stamps).
