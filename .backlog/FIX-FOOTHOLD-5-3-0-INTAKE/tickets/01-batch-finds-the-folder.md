# 01 — The batch finds the adopted folder of a release

Status: ✅ done

`Resolve-MissionFolder.ps1` matches a release archive to the folder of the same theatre.

- `Get-MissionTheatre` reads both key forms: `["theatre"] = "…"` (inside a `.miz`) and `theatre = "…"` (an adopted folder's exploded table).
- Only folders `convert-other` adopted are candidates: they carry `convert-other-state.yaml`.
  The Open Training and demo missions in the same folder no longer make a theatre ambiguous.

Left as it is: Sinai and Sinai North are two Foothold missions on one map (`SinaiMap`), so they stay ambiguous; their archives are copied under the folder names, which the name rule picks first.
Documented in the batch's help and in `doc/mission-maker/FOOTHOLD.md`.

The first refresh after this lot still needs the renamed archives: the state file did not exist before, and is written by that refresh.

Tests: `test/python/tools/test_foothold_batch_folder_matching.py` (normalized form, a non-adopted folder on the same map).
