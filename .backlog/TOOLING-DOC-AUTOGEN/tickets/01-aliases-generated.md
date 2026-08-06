# 01 — Coverage check instead of an ALIASES generator

Status: ✅ done
Type: feat
Files: `veaf_build/docs_check.py`, `doc/ALIASES.{md,en.md}`, `src/scripts/veaf/veafShortcuts.lua`, `test/`

## What this ticket asked for, and why it was not done

> *"`doc/ALIASES.md` is 8 KB whose entire content is a rendering of `veaf_libs/data/veaf-units.yaml`.
> There is no prose to lose."*

Both halves were wrong, and the ticket's own instruction — read the diff before replacing anything —
is what surfaced it:

- **Wrong source.** `veaf-units.yaml` holds *spawn* units and groups (`aliases: [hq7], unitType:
  HQ-7_LN_SP`), for `_spawn unit <alias>`. The **marker** aliases this page documents are registered
  at runtime in `veafShortcuts.lua` through `VeafAlias:new():setName("-hq7")`.
- **There is prose.** Thematic French sections, a hand-written description per alias, a Notes column
  carrying things like "Niveau de défense 1–5 (aléatoire)". None of it exists in any data file.

So generation would have destroyed the page. Shipped as a **coverage check**: every alias declared in
`veafShortcuts.lua` must appear as `` `-alias` `` in both language versions.

## Delivered

- [x] `CoverageRule` for the 128 aliases → `doc/ALIASES.{md,en.md}`, matching on the backticked form
      so a bare mention in prose does not satisfy it.
- [x] The 5 undocumented aliases written up in both languages: `-cesar`, `-shell`, `-flak` in a new
      *Simulated shelling* subsection under Artillery, `-login` / `-logout` under Utility Commands.
- [x] The `hidden` concept **kept and repaired**, not removed — see the PRD. It was deleted on the
      finding that nothing read it, which was wrong: `veaf_shortcuts_scanner.py` reads it to build
      what `list_shortcuts` serves to an AI. The real defect was a stale committed
      `veaf-shortcuts.json` overriding that parser, which had left a test red on `develop`.
- [x] Tests, including that the mention format is honoured and that **every** configured page is
      checked, not just the first — otherwise a translation could rot unseen.

## Acceptance criteria

- [x] Reported 10 alias gaps before, zero after.
- [x] `stylua --check` and `luacheck` clean on `veafShortcuts.lua` (only its comment changed).
- [x] `poetry run test-lua` not needed: the only Lua change is a comment. (It could not run here
      anyway — no Lua 5.1 since `FIX-LUA-RUNNER-VERSION-CHECK`.)
