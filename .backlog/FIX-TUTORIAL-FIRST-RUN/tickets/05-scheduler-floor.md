# 05 — A task due now still runs

Status: 🔄 in-progress

Type: fix

## The report

Paluche activated a combat zone, asked for smoke, got the confirmation message and no smoke.
Illumination flares from the same menu worked.

*"l'activation de la smoke sur la zone n'a pas fonctionné. J'ai bien un message qui confirme
l'activation mais la fumée n'apparaît pas (contrairement aux fussées éclairantes)."*

## What the code says

`VeafCombatZone:popSmoke` → `veafSpawn.spawnSmoke`, and with the default `shells = 1` the one and
only shell is scheduled for **exactly `timer.getTime()`**
([`veafSpawnEffects.lua:68`](../../../src/scripts/veaf/veafSpawnEffects.lua)). The confirmation he
saw (`combatzone.smoke_requested`) is emitted *after* `spawnSmoke` returns, so nothing raised: the
effect was scheduled and never appeared.

Every site in the framework that can schedule at or before "now" is in that one file:

| Site | Time |
|---|---|
| `spawnBomb`, first shell | `timer.getTime()` |
| `spawnSmoke`, single shell | `timer.getTime()` |
| `spawnSignalFlare`, single shell | `timer.getTime()` |
| `spawnSmoke`, the explosion under a multi-shell plume (`:66`) | `timer.getTime() - 1` — **in the past** |
| `spawnIlluminationFlare` | `timer.getTime() + 0.75` at the earliest |

The illumination flare — the one that worked — is the only one with a strictly positive delay.

Until #828 (2026-08-28, shipped in 6.18.0) this went through `mist.scheduleFunction`: MiST ran its
own task list from a 10 ms loop and executed anything overdue at the next tick, so a past-due task
was never lost. It now goes through one native `timer.scheduleFunction` per task
([`veafScheduler.lua:128`](../../../src/scripts/veaf/veafScheduler.lua)).

## What is not proven

Whether DCS runs a function whose scheduled time has already elapsed. That is the hypothesis, and
settling it needs the game — there is no DCS on this machine and David had no mission running when
asked (2026-09-02). The fix is therefore **defensive on the cause and correct on the contract**: a
task due now or overdue must still run, which MiST guaranteed and this framework quietly stopped
guaranteeing. If DCS turns out to honour past times, the floor costs one tick and changes nothing.

## The fix

`veafScheduler.scheduleFunction` clamps the first run to no earlier than the next tick, restoring
MiST's behaviour for every caller instead of patching three call sites. `veafSpawnEffects.lua:66`
then means "just before the smoke" rather than "one second ago", which is what it was after.

## Definition of done

- [ ] A task scheduled for `timer.getTime()`, or earlier, is armed for a time in the future
- [ ] Repetition and stop time keep their current semantics
- [ ] Unit tests: due-now, overdue, comfortably-future (unchanged), and one asserting `spawnSmoke`
      reaches `trigger.action.smoke` with a usable point — the wiring, not the handler
- [ ] `luacheck` + `stylua --check` clean
- [ ] Lua coverage floor bumped per the ratchet policy
