# FIX-TRIPACK-FIELD-REPORTS — three defects a 6.19.0 flight surfaced, one of them our own fix left half-applied

Status: ⬜ ready

Origin: Tripack's session of 2026-09-03 on `Snowfox_20260903.miz` (Persian Gulf), reported the same
evening with screenshots and `dcs.log`. Three reports, unrelated in the code and related in time:
they all came out of one flight against the current release. He sent the mission itself, its
Skynet-off twin and the mission sources on **2026-09-05**, which is what turned two of the three
open questions into measurements.

The log carries two missions built with different toolchains, which is what makes it worth reading:

| Mission loaded | VEAF | Skynet |
|---|---|---|
| 18:10:55, 18:17:01 | 6.16.0+87da906 | 3.4.0RP (10.09.2025), stock |
| 18:11:35, 18:17:51 | **6.19.0+01e150d** | **3.4.0RP-VEAF build 30.08.2026** |

Everything below was observed on the 6.19.0 pair.

## What he hit

| # | Report | Status of the diagnosis |
|---|---|---|
| 1 | *"tous mes sam sont inactifs … je n'arrive pas à afficher le statut, ni les contacts"*, with `SKYNET.enabled: true`. Re-run with Skynet switched off: *"les sam fonctionnent nickel, c'est donc skynet qui est pété"* | **root cause held**, see below |
| 2 | *"le déplacement automatique des unités CZ est un peu buggé"* — ZU-23s of a combat zone standing kilometres out to sea on the F10 map, while the editor has them on Abu Musa island | **partly**: a second defect on the same path is now fully explained (six naval groups never spawn, tickets 02+03); the sea-borne ZU-23s are still **not** explained, but the hypothesis is bounded |
| 3 | *"réaction bizarre des avions de la QRA, tout se déclenche mais ils font leur nav tranquilos … la semaine passée ils étaient méchants, rien touché de mon côté depuis"* | **cause held**: the clone drops the group's `task` (here `'CAP'`), a field MiST forwarded and the record does not carry |

## Report 1 — the fix of #908, not applied to its twin

`SkynetIADS:activate` schedules its contact-evaluation cycle with a **hardcoded start time of `1`**
— one second of mission time, long past by the time an IADS initialises (18:29:48 in the log, some
three minutes in). Skynet does this at three sites; `goSilentToEvadeHARM` is the only one that
passes an absolute future time.

MiST tolerated it: its own 10 ms loop ran anything whose time had come *or gone*
([`mist.lua:1526`](../../src/scripts/community/mist.lua)). The compatibility module that replaced
MiST inside the fork ([#846](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/846),
2026-08-30) hands the value straight to the native timer
([`skynet-iads-compiled.lua:197`](../../src/scripts/community/skynet-iads-compiled.lua)) — with a
docstring promising the floor it does not implement: *"a time already past means the next tick"*.

**This is the same defect as FIX-TUTORIAL-FIRST-RUN ticket 05**, found four days earlier on
`spawnSmoke` and fixed there by clamping in `veafScheduler`
([`veafScheduler.lua:139`](../../src/scripts/veaf/veafScheduler.lua)), whose comment records the
symptom in so many words: *"a dropped task leaves no trace at all: `spawnSmoke` reported success and
no smoke ever appeared."* The Skynet twin lives in another repository and was not carried along.

One dropped task explains all three of Tripack's symptoms at once:

- `evaluateContacts` never runs → the IADS never wakes the radars it darkened on registration → **every
  SAM inactive**;
- `printSystemStatus()` is called at the end of that same cycle
  ([`:1923`](../../src/scripts/community/skynet-iads-compiled.lua)) → the radio menu flips the flag and
  **nobody ever reads it** — status and contacts stay blank;
- Skynet off, the SAMs are untouched → **they work**.

No Skynet error anywhere in the log, which is exactly the signature: nothing raises, a task is lost.

## Report 2 — six naval groups of a combat zone never spawn

Certain, and reproduced identically on both 6.19.0 loads:

```
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain
  for [CMBT_BANDAR_E_JASK - Cargo Ship]     (also - Navy)
  for [CMBT_HAVADARYA - Submarine]          (also - Navy, - Cargo Ship)
  for [CMBT_RAJAEI - Cargo Ship]
```

`_drawOrigin` returns `nil`, `_spawn` returns `false`, the group is not created. Upstream of it,
thirteen `findSpawnPoint` calls fail at 50 m — mechanical, since
[`acceptableGroundPoint`](../../src/scripts/veaf/veaf.lua) only ever accepts **dry land** and
[`spawnElement`](../../src/scripts/veaf/veafCombatZone.lua) calls it for every element of a zone,
ships included. A hull will never find its point.

**Measured 2026-09-05, and the answer inverts the log's suggestion.** The six are `ship` groups, so
they are validated against water and a hull at anchor passes. They are refused because the search
**succeeded**: they lie alongside a quay, `findSpawnPoint` finds dry land within 50 m and moves them
onto it, and the terrain check then correctly refuses a ship on a quay. The twelve ships whose search
*failed* are the ones that spawn — they sit far enough out that no land is within reach, so they keep
their declared position. The cross-check is exact: not one refused group appears among the thirteen
logged failures, and the nearest is 16 km away. Ticket 02 therefore fixes all six; ticket 03 keeps
the instrumentation that would have made this readable from the log alone.

The sea-borne ZU-23s stay unexplained, but the mission moved the question. This zone's five ZU-23s are
**one group spread over 4.3 km** — Tripack ringed the island with them. The spawn translates a whole
group by one offset measured against its first unit, so anchoring on the wrong unit displaces every
ZU-23 by kilometres. The earlier reasoning ruled that out on the spawn radius (50 m), which was the
wrong quantity to look at. Ticket 04 carries the three candidate anchors.

## Report 3 — a field the editor sets and the clone drops

The log gave nothing (`VEAF-QRA` speaks only at `debug`), and the first hypothesis — a route pushed
without its engagement tasks — was checked and ruled out: `getGroupRoute` does project each point's
`task`. The mission sources named the real one.

`QRA_SOUTH` deploys pre-placed groups, so it clones them. `CAP_AL_MINHAD-1` carries `task = 'CAP'`,
`taskSelected = true` and an `EngageTargetsInZone` on waypoint 2. The clone reads
`veafMissionDb.getGroupRecord`, whose ten fields do **not** include `task` — the word does not appear
anywhere in that file — and nothing puts it back before `coalition.addGroup`. So a CAP flight reaches
DCS with its per-waypoint engagement intact and **no mission task at all**.

MiST carried it (`mist.DBs[...].task = group_data.task`, `mist.lua:264`), which places the loss exactly
between the version where Tripack's QRA was *"méchante"* and the one where it is not. The same gap
drops `taskSelected`, `uncontrolled`, `frequency`, `modulation`, `communication` and `radioSet` from
**every** clone and respawn in the framework, not just the QRA's.

## Constraints

- **Ticket 01's change is in another repository.** The artefact here is compiled, so a local patch is
  overwritten by the next regeneration. `vendored.yaml` states the three steps and the one that gets
  forgotten: recompile, **run stylua**, re-apply the `RP-VEAF` label.
- Ticket 04 must not ship a guess: its cause is still unnamed, and the ticket says so rather than
  fixing the first plausible thing.
- Ticket 05's field list is **enumerated from the mission schema**, not sampled from the seven found
  in this mission — the sweep is the deliverable.
- Quality ratchet: `veafDcsSpawner` and `veafCombatZone` are touched by tickets 02/03, so their mypy
  exclusions — if any — go, and the Lua coverage floor moves with the tests added.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Skynet's scheduler keeps the promise its docstring makes](tickets/01-skynet-scheduler-floor.md) | fix | 🧑 |
| 02 | [A zone's naval element looks for water, not for dry land](tickets/02-naval-elements-look-for-water.md) | fix | ✅ |
| 03 | [Why the terrain check refuses a ship already at sea](tickets/03-measure-the-naval-refusal.md) | fix | ✅ |
| 04 | [ZU-23s of a combat zone come up kilometres out to sea](tickets/04-units-displaced-out-to-sea.md) | fix | ⬜ |
| 05 | [A cloned group loses the mission task the editor gave it](tickets/05-qra-scrambles-without-engaging.md) | fix | ✅ |

**All five are workable.** Tripack sent `Snowfox_20260903.miz`, its Skynet-off twin and the mission
sources on 2026-09-05, and the measurements below replaced three open questions with answers. Only
ticket 04 still lacks a named cause, and it now has a bounded hypothesis to test rather than a blank.
