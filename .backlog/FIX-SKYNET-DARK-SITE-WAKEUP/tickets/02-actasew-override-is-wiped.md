# 02 — Remove the two dead `actAsEW` reset blocks

Status: ⬜ ready

## Decision

Settled with Flogas, 2026-09-19: **the two blocks are useless, remove them and clean up around
them.**

## The history, which is what makes them useless

At the start, VEAF forced the large systems into EW-watch mode — they watched permanently and saw
for themselves. A block was then added so that when a **real** EWR joined the network after
start-up, those large systems dropped their watch duty: with a proper radar on station they no
longer needed to do the job themselves. It sat at the end of the network-initialisation block, and
a twin was placed in the per-group path.

Then the forcing was dropped. `a68dfd32` (2022-04-05, *"IADS: removed defaulting to EWR for SAM
sites"*) **flipped both blocks from `true` to `false`** rather than deleting them, adding `Mcc-sr`
false, `SA-5` false and `Ewr` true; `7ead5793` (2022-05-20) removed `Mcc-sr` and `Ewr`. Flogas
carried the list forward in `3002aaad` (2023) and `d4e1b66c` (2024).

Since nothing forces the watch on anymore, telling those five types to drop it asks for something
that is already true: Skynet builds every radar element with `instance.actAsEW = false`
(`skynet-iads-compiled.lua:2585`). The blocks have no purpose left.

## What they still do, all of it unwanted

1. **They kill an explicit request.** `getSAMSitesByNatoName` returns *every* site of that type in
   the network, so a SA-10 marked as a watch — by the `ewr` spawn option or by hand in
   `mission-script.lua` — is silenced. Worse, the order of operations in `initializeIADS` means the
   enrolment loop sets the watch and the block right after it undoes it, so on these five types
   `ewr` has **never** worked, not even at first start-up.
2. **They send a stray `goDark()`.** `setActAsEW` calls `goDark()` outside its state-change test, so
   every group joining the network sends an extinction order to all SA-10, SA-6, SA-5, Patriot and
   Hawk in it. Bounded by `goDark`'s own guards and repaired on the next cycle, so minor — but it
   goes away with the blocks.
3. **They can break Flogas's point-defence mechanism.** `pointDefencesGoLive()` puts a point defence
   into `actAsEW(true)` so it watches while the site it protects is silenced by an anti-radiation
   missile. A point defence of one of the five types gets switched straight back off. Unlikely in
   practice, real all the same.

## What to remove

| Where | What |
|---|---|
| `veafSkynetIadsHelper.lua:1549-1560` | the block, its `if not batchMode and not forceEwr and not pointDefense` guard, and the "Specific configuration applied" trace |
| `veafSkynetIadsHelper.lua:1635-1642` | the twin block and its comment |
| `veafSkynetIadsHelper.lua:1370` | `batchMode` then only feeds one trace line. Keep both — the trace is useful when reading a log |
| `test/lua/test_veafSkynetIadsHelper.lua:116` | `natoMock` and `getSAMSitesByNatoName` in `_makeMockIads` exist only to absorb these calls |

## The one risk to check first

A mission already using `ewr` on a SA-10, SA-6, SA-5, Patriot or Hawk will see that site **really
lit permanently** after the fix, where it is dark today. That is what its author asked for, but
nobody has ever seen it happen, so it will read as a regression. The option is documented nowhere,
so this is unlikely — check the VEAF mission repositories before merging.

## Definition of done

- Both blocks gone, the test mocks they required gone with them.
- A new test: mark a SA-10 as an EW watch, add another group to the network, assert the watch
  survives. It fails today.
- `poetry run test-lua` green, `CHANGELOG.md` updated.
