# 03 — List the CSAR settings, FR and EN

Status: ⬜ ready

## What is missing

`CSAR.lua` defines 34 scalar settings reachable from `modules.CSAR.settings`. The guide names 3, as
examples. A mission maker looking for one of the other 31 finds nothing and concludes, as Tripack
did, that Lua is required.

The 34, grouped the way a mission maker thinks about them rather than the order they appear in the
script:

- **Who gets rescued** — `enableForAI`, `enableForRED`, `enableForBLUE`, `csarOncrash`,
  `countCSARCrash`, `allowDownedPilotCAcontrol`
- **Who can fly the rescue** — `enableAllslots`, `useprefix`, `enableSlotBlocking`, `max_units`
- **Lives and sanctions** — `csarMode`, `maxLives`, `reenableIfCSARCrashes`,
  `disableAircraftTimeout`, `disableTimeoutTime`, `destructionHeight`
- **Finding the survivor** — `coordtype`, `coordaccuracy`, `autosmoke`, `bluesmokecolor`,
  `redsmokecolor`, `radioSound`, `requestdelay`, `messageTime`
- **Picking them up** — `loadDistance`, `extractDistance`, `pilotRuntoExtractPoint`, `loadtimemax`,
  `weight`, `allowFARPRescue`
- **The survivor's own state** — `immortalcrew`, `invisiblecrew`, `downedPilotCounterRed`,
  `downedPilotCounterBlue`

## What done means

- A table in the CSAR section of the guide: setting, default, one line of effect. The default comes
  from `CSAR.lua`, read at the time of writing, not from memory.
- The table says plainly which settings are **not** reachable this way and why: `aircraftType`,
  `csarFixedUnits`, `bluemash`, `redmash` are tables of tables and need the Lua callback. Today the
  guide says "complex settings" without saying which, which is how a plain boolean got mistaken for
  one.
- `csarPrefix` is documented according to what ticket 01 delivered, not according to what the
  current example claims.
- FR and EN ship together, the page keeps its explicit English anchors, and
  `poetry run docs-check` passes.
- `services/support-bot/scripts/refresh_doc_pages.py` is re-run and its output committed —
  `docs-check` does not catch that, and the service's own CI job does.

## What not to do

Do not generate the table from `CSAR.lua` at build time. It is a vendored third-party script whose
comments are uneven (`weight`, `loadtimemax` and the two counters carry none), and half the value
here is a sentence written for a mission maker rather than the author's own note to self. Write it
by hand, once, and let the ratchet catch it if the script changes.
