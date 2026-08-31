# 01 — Guard the DCS group on the spawn path

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafSpawnAircraft.lua`

## The change

Check what `Group.getByName` returned before the five dereferences that follow. The last of them
(`getController()`) is not a log line, so this is not a logging fix: decide what the function does
when DCS cannot find the group it just created.

Follow the shape PR #872 used for the same defect in `veafCombatMission.lua` — same warning, same
kind of test through the mocks — so the two read alike for whoever meets them next.

## Definition of done

- [x] No dereference of `_dcsSpawnedGroup` is unguarded
- [x] The nil case is reported at `warning`, naming the group
- [x] The chosen behaviour after the failure is deliberate and stated in the PR
- [x] The normal path is unchanged
- [x] A test drives the nil case and fails without the guard — verified by removing it
- [x] `poetry run test-lua` green, `stylua --check` clean
