# 03 — List the CSAR settings, FR and EN

Status: ✅ done

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
- The table says plainly which settings are **not** reachable this way and why. Today the guide
  says "complex settings" without saying which, which is how a plain boolean got mistaken for one.

  **Corrected while writing it — this ticket had it wrong.** Only `aircraftType` is a table of
  tables: `CSAR.lua:21` opens it empty and fills it by key (`csar.aircraftType["UH-1H"] = 8`).
  `csarFixedUnits` (line 36), `bluemash` (129) and `redmash` (142) are **flat lists of strings**,
  exactly like `csarPrefix`, so after ticket 01 they are written in YAML like any other list. So the
  count is 34 scalars **plus 4 lists reachable from YAML**, and **one** setting that is not.
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
