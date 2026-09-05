# 01 — Skynet's scheduler keeps the promise its docstring makes

Status: 🧑 waiting-human

Type: fix

## The report

Tripack, 2026-09-03, on a mission built with 6.19.0 and `SKYNET.enabled: true`:

*"IADS fonctionne avec la dernière version chez vous? tous mes sam sont inactifs, et je n'arrive pas
à afficher le statut … ni les contacts. pourtant activé"*

Then, half an hour later, the measurement that closes the question:

*"même mission relancée en l'ayant coupé, les sam fonctionnent nickel. c'est donc skynet qui est
pété"*

## What the code says

`SkynetIADS:activate` arms its contact cycle with a **start time of `1`** — one second of mission
time:

```lua
self.ewRadarScanMistTaskID = SkynetIADSUtils.scheduleFunction(SkynetIADS.evaluateContacts, { self }, 1, self.contactUpdateInterval)
```

In Tripack's log the IADS initialises at 18:29:48, about three minutes into the mission, so that
time is long past. Two more sites do the same: `scanForHarms` and `SkynetIADSJammer:masterArmOn`.
Only `goSilentToEvadeHARM` passes `timer.getTime() + n`.

MiST accepted a past time by construction — its task list was walked by a 10 ms loop that ran
anything with `t <= now` ([`mist.lua:1526`](../../../src/scripts/community/mist.lua)). The
compatibility module written for [#846](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/846)
hands the value to the native timer unchanged
([`skynet-iads-compiled.lua:197`](../../../src/scripts/community/skynet-iads-compiled.lua)), while
its own docstring says the opposite:

> `@param startTime` seconds since mission start at which to run it first; **a time already past
> means the next tick**

It does not. That is the whole defect.

## Why all three symptoms are this one task

| Symptom | Mechanism |
|---|---|
| every SAM inactive | Skynet darkens a site's radar when it registers it and only re-enables it from the contact cycle |
| status blank | `printSystemStatus()` is the last statement of `SkynetIADS:evaluateContacts` ([`:1923`](../../../src/scripts/community/skynet-iads-compiled.lua)); the radio menu only flips a flag that this call reads |
| contacts blank | same call, same flag |
| Skynet off, SAMs fine | with no IADS nothing darkens them |

No `SKYNET` error appears anywhere in `dcs.log` — the signature of a lost task rather than a crash.

## The precedent

This is the same defect as **FIX-TUTORIAL-FIRST-RUN ticket 05**, found on 2026-09-02 on
`spawnSmoke` and fixed by clamping inside `veafScheduler`
([`veafScheduler.lua:139`](../../../src/scripts/veaf/veafScheduler.lua)). That fix stopped at the
repository boundary: Skynet's compatibility module is a second implementation of the same
replacement, living in the fork, and it was not carried along.

Whether DCS truly discards a call scheduled for an elapsed time is **still unproven** — it is item
R12 of [`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md). It does not need to be settled here:
the contract MiST held is that a task due now or overdue still runs, and restoring it costs one tick
if DCS turns out to be forgiving.

## The fix

In [`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS), `SkynetIADSUtils.scheduleFunction`
clamps the first run to no earlier than the next tick, exactly as `veafScheduler` does. One place,
not three call sites, so any future Skynet release keeps the guarantee.

Then, per [`vendored.yaml`](../../../vendored.yaml) and in this order:

1. recompile `skynet-iads-compiled.lua` from the fork's sources (`build-tools/build-compiled-script.ps1`);
2. **run stylua on it** — the step that gets forgotten, and skipping it turns the next sync into a
   4000-line reformatting diff;
3. re-apply the `RP-VEAF` version label, and bump the build date in the label and in `vendored.yaml`'s
   `pinned:`.

## Definition of done

- [x] A Skynet task scheduled for a time already elapsed runs at the next tick
- [x] Repetition, stop time and `removeFunction` keep their current semantics
- [x] Test covering due-now, overdue, and comfortably-future — **not in the fork**: its `unit-tests/`
      run inside DCS from a `.miz` on top of MiST, so there is no headless harness to add a case to.
      The coverage lives on this side, in `test/lua/test_skynetIadsUtils.lua`, asserted against the
      vendored artefact itself. Verified both ways: three of its eight cases fail on the pre-fix
      artefact.
- [x] Artefact regenerated, stylua'd, label and `vendored.yaml` `pinned:` updated together
      (build 05.09.2026). Diff against the previous artefact is two hunks — the version banner and
      the 24 added lines — and nothing else moved.
- [x] `luacheck` + `stylua --check` clean on `src/scripts/veaf/ test/lua/`
- [x] In-game verification queued in `DCS-SESSION-TODO.md` as **R13**, paired with R12: both fixes
      rest on the same unproven wager about the native timer, so they are checked in one session

## What shipped

- Fork: [VEAF/Skynet-IADS](https://github.com/VEAF/Skynet-IADS) branch `fix/scheduler-past-start-time`
  — `MINIMUM_DELAY = 0.01` in `skynet-iads-utils.lua`, clamping the **first** run only. Repetition is
  re-armed from `timer.getTime()` inside `runScheduledTask` and so is future by construction;
  `stopTime` is a comparison, not a delay.
- One open follow-up: `vendored.yaml`'s watch pin for `VEAF/Skynet-IADS`
  (`demo-missions/skynet-iads-compiled.lua`, still `820d3cc0eb85`) can only be moved once the fork PR
  is merged, since it names a commit on the fork's `master`. Until then the drift watcher will flag
  the entry, correctly.
