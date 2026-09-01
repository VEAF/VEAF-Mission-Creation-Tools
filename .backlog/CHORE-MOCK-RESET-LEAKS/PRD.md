# CHORE-MOCK-RESET-LEAKS — global state the mock reset does not reset

Status: ✅ done

Origin: `dcs_mocks.reset()` not clearing `veafMissionDb.spawnedNames` trapped two separate pieces
of work on 2026-08-31 — the CSAR initialisation lot, and the aircraft-spawn guard lot. Both fixed
it in their own `setUp`. Nobody fixed it at the source.

## Why it is worth a lot rather than a third `setUp` line

The second time it bit, it did **not** produce a red test. It produced a test that passed for the
wrong reason: a leftover name made the clone-name uniquifier append ` #2`, so the "group is found"
probe missed its lookup — testing the nil case twice while appearing to cover both. Only probing
both paths caught it. A leak that turns a passing test into a lie is worse than one that breaks it.

## It is a family, and `spawnedNames` is not even its worst member

Global VEAF state cleared **by hand** in the Lua suites, counted on `develop`:

| Cleared manually | Times |
|---|---|
| `veafSkynet.structure` | 12 |
| `veafCarrierOperations.carriers` | 12 |
| `veafSpawn.spawnedConvoys` | 8 |
| `veafMissionDb.spawnedNames` | 8 |
| `veaf.ImportantUnitsByGroupPattern` | 8 |
| `veafSkynet.iadsSamUnitsTypes` / `iadsEwrUnitsTypes` | 6 each |
| `veafMissionDb.humansByName` | 5 |
| `veafAssets.assets` | 5 |
| `veafSpawn.commandHandlers` | 4 |
| `veafSkynet.declaredSpawns` | 4 |
| `veafSecurity.groupElevations` | 4 |

Twelve distinct pieces of state, and every suite has to guess which ones concern it. The one that
guesses wrong gets a test that passes for the wrong reason.

## The precedent is already in the file

`reset()` does exactly this for CTLD, with the reason written down:

```lua
-- Back to CTLD's shipped default, or a test that switches sling loading off leaks into the next one.
CTLDConfig._instance.settings = { enableHoverSlingload = true }
```

The principle is established. The VEAF-side state was simply never added.

## Judge each, do not sweep them all in

Some of these are genuine leaks; others may be deliberate configuration a suite sets on purpose and
would be wrong to clear. The deliverable is a decision per entry, not a bulk move — and the reason
in a comment, as CTLD's already has.

## The decision, entry by entry

`dcs_mocks.resetVeafRuntimeState()` now clears the state that is a **runtime accumulation**: empty
when its module loads, filled only by the code under test, and never something a suite arranges.
Everything else stays where it is.

| State | Verdict | Why |
|---|---|---|
| `veafMissionDb.spawnedNames` | **leak → `reset()`** | Runtime registry. A leftover name makes the clone-name uniquifier append ` #2`; that is the bug that started this lot |
| `veafSpawn.spawnedNamesIndex` | **leak → `reset()`** | The other half of the same mechanism — the per-template ` #0001` counter. Not in the count above; found while fixing its sibling |
| `veafSpawn.spawnedConvoys` | **leak → `reset()`** | Runtime registry. A convoy from a previous test is one more candidate for "the closest convoy" |
| `veafMissionDb.humansByName` | **leak → `reset()`** | The player roster, rebuilt by `initialize()`. A pilot registered by one test must not sit in the next test's slot |
| `veafSpawn.spawnedUnitsCounter` | **leak → `reset()`** | Not in the count above. A running total that only looked like a constant because its test ran before every spawn in the file — see below |
| `veafSpawn.commandHandlers` | setting, stays | Filled at module **load** by every `registerCommandHandler` call. Clearing it centrally breaks the five `TestSecrev2ShowMfd` tests, which read it to find the `afac` and `cap` handlers — measured, not assumed |
| `veaf.ImportantUnitsByGroupPattern` | setting, stays | Ships **non-empty**; `{}` is not its default. One suite asserts the shipped patterns only name types the generated database knows, and the suite that wants `{}` already saves and restores |
| `veafCarrierOperations.carriers` | setting, stays | Ten of the twelve occurrences are inside test bodies: an empty carrier list is the case under test ("no carriers → early return"), not leftovers |
| `veafSkynet.structure` / `declaredSpawns` / `iadsSamUnitsTypes` / `iadsEwrUnitsTypes` | setting, stays | These suites never call `dcs_mocks.reset()`; each `setUp` builds a whole world (networks, `initialized`, the `SkynetIADS` stub, the integration mode). An empty type table is a deliberate starting point — in a mission `initialize()` fills it from the Skynet database |
| `veafAssets.assets` | setting, stays | `veafAssets.buildAssetsDatabase()` clears it itself, and every clearing is paired with the suite's own `veafAssets.Assets` dataset. Where it stands alone (`test_buildRadioMenu_empty_assets`) the empty table is the case under test |
| `veafSecurity.groupElevations` | setting, stays | Leak-shaped, but self-contained: both suites clear it in `setUp` **and** `tearDown`, and neither uses `dcs_mocks.reset()` as its hygiene call |

Two order dependencies were also fixed at their source, because a suite that empties a **load-time**
registry and walks away leaves the next suite reading an empty table:

- `TestVeafSpawnCore`, `TestSpawnSilenceIsNotSecurity` and `TestSpawnSilenceSurvivesRescheduling`
  now save and restore `veafSpawn.commandHandlers`. Before: running `TestVeafSpawnCore` ahead of
  `TestSecrev2ShowMfd` failed five tests. Alphabetical order hid it.
- `TestVeafIsEnabled` replaced the whole `veaf.config` and never put it back, leaving
  `ctld.enable = false` behind. `veaf.isCtldReady()` reads exactly that, so
  `TestVeafCtldSlingloadToggle` silently stopped logging anything.

And `TestVeafSpawnConstants:test_spawnedUnitsCounter_starts_at_zero` asserted a running total, not a
constant. It passed only while it ran before every spawn in the file; in a shuffled order it read
whatever the previous suite had left. It now asserts what is actually guaranteed — that a test
starts from zero — and the counter is cleared centrally.

## How it was proved

- **Which entries are settings was measured, not guessed.** All thirteen were added to `reset()` at
  once and the suite run: only `commandHandlers` broke anything. Passing is not proof of correct,
  though — `ImportantUnitsByGroupPattern` also "passed" while wrongly cleared, because the suite that
  reads the shipped table never calls `reset()`.
- **The manual clearings `reset()` covers were removed**, and the suite stays green.
- **Randomised order.** luaunit's `--shuffle` is not usable as shipped: it seeds `math.random` when
  it loads, then every suite loads `dcs_mocks.lua`, which replaces `math.random` with a fixed
  sequence — so the "shuffle" is the same permutation every run. With a real generator driving the
  reordering, 48 randomised orders are green. Before the fixes, the same orders exposed the two
  dependencies listed above.

## Definition of done

- [x] Every entry above is either cleared by `reset()` or documented as deliberately left alone
- [x] The manual clearings that `reset()` now covers are removed from the suites — leaving both is
      how the next person learns nothing
- [x] The full Lua suite passes, and passes **in a different order** if the runner allows it: an
      order-dependent green is exactly what this lot is about
- [x] `reset()` says why each addition is there, following the CTLD comment's example

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Reset what leaks, justify what stays](tickets/01-reset-what-leaks.md) | chore | ✅ |
