# 01 — Guard the DCS group on the spawn path

Status: ⬜ ready

Type: fix · File: `src/scripts/veaf/veafSpawnAircraft.lua`

## The change

Check what `Group.getByName` returned before the five dereferences that follow. The last of them
(`getController()`) is not a log line, so this is not a logging fix: decide what the function does
when DCS cannot find the group it just created.

Follow the shape PR #872 used for the same defect in `veafCombatMission.lua` — same warning, same
kind of test through the mocks — so the two read alike for whoever meets them next.

## Definition of done

- [ ] No dereference of `_dcsSpawnedGroup` is unguarded
- [ ] The nil case is reported at `warning`, naming the group
- [ ] The chosen behaviour after the failure is deliberate and stated in the PR
- [ ] The normal path is unchanged
- [ ] A test drives the nil case and fails without the guard — verified by removing it
- [ ] `poetry run test-lua` green, `stylua --check` clean
