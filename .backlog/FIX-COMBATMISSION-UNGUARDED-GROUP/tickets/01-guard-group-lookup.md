# 01 — Guard the group lookup

Status: ⬜ ready

Type: fix · File: `src/scripts/veaf/veafCombatMission.lua`

## The change

Check what `Group.getByName` returned before calling `:getName()` and `:getUnits()` on it. When it
is `nil`, log a warning naming the group and carry on — the spawn itself succeeded, only the
follow-up lookup failed.

## Definition of done

- [ ] `Group.getByName` returning `nil` no longer raises
- [ ] The case is reported at `warning`, naming the group
- [ ] The normal path is unchanged
- [ ] A test drives the nil case through the DCS mocks and fails without the fix
- [ ] The sweep of similar unguarded dereferences is reported in the PR
- [ ] `poetry run test-lua` green, `stylua --check` clean
