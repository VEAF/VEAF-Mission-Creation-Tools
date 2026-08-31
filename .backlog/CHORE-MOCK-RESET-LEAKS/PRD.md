# CHORE-MOCK-RESET-LEAKS — global state the mock reset does not reset

Status: ⬜ ready

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

## Definition of done

- [ ] Every entry above is either cleared by `reset()` or documented as deliberately left alone
- [ ] The manual clearings that `reset()` now covers are removed from the suites — leaving both is
      how the next person learns nothing
- [ ] The full Lua suite passes, and passes **in a different order** if the runner allows it: an
      order-dependent green is exactly what this lot is about
- [ ] `reset()` says why each addition is there, following the CTLD comment's example

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Reset what leaks, justify what stays](tickets/01-reset-what-leaks.md) | chore |
