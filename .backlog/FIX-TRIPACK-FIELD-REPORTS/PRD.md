# FIX-TRIPACK-FIELD-REPORTS — three defects a 6.19.0 flight surfaced, one of them our own fix left half-applied

Status: ⬜ ready

Origin: Tripack's session of 2026-09-03 on `Snowfox_20260903.miz` (Persian Gulf), reported the same
evening with screenshots and `dcs.log`. Three reports, unrelated in the code and related in time:
they all came out of one flight against the current release.

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
| 2 | *"le déplacement automatique des unités CZ est un peu buggé"* — ZU-23s of a combat zone standing kilometres out to sea on the F10 map, while the editor has them on Abu Musa island | **partly**: the log proves a different, certain defect on the same path (six naval groups never spawn); the sea-borne ZU-23s are **not** explained |
| 3 | *"réaction bizarre des avions de la QRA, tout se déclenche mais ils font leur nav tranquilos … la semaine passée ils étaient méchants, rien touché de mon côté depuis"* | **no diagnosis**: the QRA says nothing at `INFO`, and the one plausible mechanism was checked and ruled out |

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

Why the terrain check then *also* refuses them is **not established** — a `ship` group is validated
against `veaf.WATER_TERRAIN`, and a point at sea should pass. `makeVec3`, `getRandomPointInCircle`
and `isTerrainValid` were each read and none of them loses the coordinate. Ticket 03 measures it
rather than guessing.

The sea-borne ZU-23s are a **separate** question and the scale rules out the obvious answer: this
mission's spawn radius is 50 m and the two units are kilometres offshore. No path read so far
produces that displacement. Ticket 04 holds it, waiting on data.

## Report 3 — nothing to work with yet

`VEAF-QRA` logs its load and then nothing: everything it says is `debug`/`trace` and the log is at
`INFO`. The plausible mechanism — a route pushed without its engagement tasks, which is precisely
what "they fly their nav quietly" looks like — was checked and **ruled out**:
[`getGroupRoute`](../../src/scripts/veaf/veafDcsSpawner.lua) projects `task` along with the rest.
Ticket 05 holds it, waiting on data.

## Constraints

- **Ticket 01's change is in another repository.** The artefact here is compiled, so a local patch is
  overwritten by the next regeneration. `vendored.yaml` states the three steps and the one that gets
  forgotten: recompile, **run stylua**, re-apply the `RP-VEAF` label.
- Tickets 03 to 05 must not ship a guess. Where the cause cannot be established, the ticket says so
  and asks for the measurement — David asked Tripack for details on 2026-09-05.
- Quality ratchet: `veafDcsSpawner` and `veafCombatZone` are touched by tickets 02/03, so their mypy
  exclusions — if any — go, and the Lua coverage floor moves with the tests added.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Skynet's scheduler keeps the promise its docstring makes](tickets/01-skynet-scheduler-floor.md) | fix | ⬜ |
| 02 | [A zone's naval element looks for water, not for dry land](tickets/02-naval-elements-look-for-water.md) | fix | ⬜ |
| 03 | [Why the terrain check refuses a ship already at sea](tickets/03-measure-the-naval-refusal.md) | fix | ⬜ |
| 04 | [ZU-23s of a combat zone come up kilometres out to sea](tickets/04-units-displaced-out-to-sea.md) | fix | 🧑 |
| 05 | [QRA fighters scramble and never engage](tickets/05-qra-scrambles-without-engaging.md) | fix | 🧑 |

Tickets 01 to 03 can be worked now. 04 and 05 wait on Tripack's `.miz` and a run with the VEAF logs
at `debug`; if neither arrives, the fallback is a purpose-built test mission — a small island with a
mixed land/sea combat zone and a QRA — measured in game on David's DCS.
