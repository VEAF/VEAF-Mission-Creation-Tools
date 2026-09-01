# 01 — Reset what leaks, justify what stays

Status: ✅ done

Type: chore · Files: `test/lua/dcs_mocks.lua`, the Lua suites that clear state by hand

## How to tell a leak from a setting

For each entry in the PRD table, look at *why* the suite clears it:

- **A leak**: the suite clears it because a previous test left something behind. Nothing about the
  value is specific to this suite. → belongs in `reset()`.
- **A setting**: the suite clears it to establish its own starting point, and another suite might
  legitimately want a different one. → stays where it is, with a comment saying so.

`veafMissionDb.spawnedNames` is the clear-cut case of the first kind, and the one to do first.

## Prove it works

The suite passing is not enough — it passes today. Two checks that mean something:

- remove a manual clearing that `reset()` now covers, and confirm the suite still passes;
- if the runner can shuffle suite order, run it shuffled. An order-dependent green is precisely
  what this lot exists to eliminate.

## Definition of done

- [x] `spawnedNames` is reset centrally, and the manual clearings for it are gone
- [x] Each remaining entry is handled or justified in place
- [x] Each addition to `reset()` carries its reason, like the CTLD one above it
- [x] `poetry run test-lua` green; `stylua --check src/scripts/veaf/ test/lua/` clean
- [x] The PR says, per entry, leak or setting — that table is the lasting part of this lot

## Outcome

The per-entry table lives in the [PRD](../PRD.md#the-decision-entry-by-entry). Five entries moved
into `dcs_mocks.resetVeafRuntimeState()` — `veafMissionDb.spawnedNames`, `humansByName`,
`veafSpawn.spawnedNamesIndex`, `spawnedConvoys`, `spawnedUnitsCounter` — and eight stayed where they
are, each with its reason. Three order dependencies were fixed at the source along the way
(`veafSpawn.commandHandlers` emptied and abandoned by three suites, `veaf.config` replaced and
abandoned by one, and a "constant" test reading a running total).
