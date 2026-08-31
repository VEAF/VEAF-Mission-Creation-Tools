# 01 — Guard the group lookup

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafCombatMission.lua`

## The change

Check what `Group.getByName` returned before calling `:getName()` and `:getUnits()` on it. When it
is `nil`, log a warning naming the group and carry on — the spawn itself succeeded, only the
follow-up lookup failed.

## Definition of done

- [x] `Group.getByName` returning `nil` no longer raises
- [x] The case is reported at `warning`, naming the group
- [x] The normal path is unchanged
- [x] A test drives the nil case through the DCS mocks and fails without the fix
- [x] The sweep of similar unguarded dereferences is reported in the PR
- [x] `poetry run test-lua` green, `stylua --check` clean
