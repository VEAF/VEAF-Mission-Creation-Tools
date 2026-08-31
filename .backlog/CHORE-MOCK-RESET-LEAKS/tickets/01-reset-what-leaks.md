# 01 — Reset what leaks, justify what stays

Status: ⬜ ready

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

- [ ] `spawnedNames` is reset centrally, and the manual clearings for it are gone
- [ ] Each remaining entry is handled or justified in place
- [ ] Each addition to `reset()` carries its reason, like the CTLD one above it
- [ ] `poetry run test-lua` green; `stylua --check src/scripts/veaf/ test/lua/` clean
- [ ] The PR says, per entry, leak or setting — that table is the lasting part of this lot
