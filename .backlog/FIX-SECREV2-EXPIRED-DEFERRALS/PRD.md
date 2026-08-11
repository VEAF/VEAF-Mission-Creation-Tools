# FIX-SECREV2-EXPIRED-DEFERRALS — two deferred findings whose condition came due

Status: 🔄 in-progress — ticket 01 delivered; ticket 02 needs a DCS session

## Why this lot exists

`SECREV-2` closed on 2026-08-11 with all 140 findings decided. Twenty-one are `decided-deferred`, and
**a deferral is only honest if something eventually collects it.** Two of the six older ones were
deferred *against a named condition*, and both conditions have now moved:

- **VMR-088** was deferred *"to `REFACTOR-MARKER-PARSER`, on David's call, because it is one instance of
  a family"*. **That lot closed the same day without touching it** — `veafCombatMission.lua` is not one
  of the marker parsers it migrated. So it is now deferred to a lot that no longer exists.
- **VMR-013** keeps the fiddle-server port unauthenticated *"because no DCS is available to test a change
  to the transport `FEAT-DCS-SMOKE-HARNESS` speaks through"*. The harness has since run in game, and its
  ticket 04 explicitly **keeps the hook** for driving DCS — so the dependency is real and still live,
  but nothing links the two.

Found while restoring the triage that archiving `SECREV-2` had deleted. Neither is tracked anywhere
else, and both would have gone quiet.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Read a unit's life once, not four times](tickets/01-vmr088-unit-life-read-once.md) | ✅ |
| 02 | [The fiddle-server port: re-anchor the deferral or close it](tickets/02-vmr013-fiddle-port.md) | 🧑 |

**01 is a small, self-contained correctness fix** and can be done now. **02 needs a DCS session** and is
coupled to `FEAT-DCS-SMOKE-HARNESS` ticket 04, so it is `🧑 waiting-human` — an agent should not pick it
up, and its first job is to decide whether it should exist at all or become a line in the harness ticket.

## What this lot is not

Not the 794-call logging chantier. VMR-088's triage entry measured **794 pre-formatted trace/debug calls
across `src/scripts/veaf/`** and David's verdict was *"that is a lot, not a finding"* — that stands. This
lot fixes the **correctness** half of VMR-088 at its one site, and leaves the family alone.
