# 02 — Persist a warehouses change to disk

Status: ✅ done 2026-08-16
Type: fix
Files: `src/python/veaf-tools/mission_tools/miz_tools.py`,
`test/python/mission_tools/test_miz_tools.py`

## The defect

`set_airbase_coalition` returned `{"airbase": "Deir ez-Zor", "coalition": "BLUE",
"dynamic_spawn": true, "durable": true}` and changed nothing on disk. Measured while investigating
ticket 01: the folder's `warehouses` file was **69 bytes before and after** the call.

The cause is one sentence in `write_mission_folder`'s own docstring — *"Rewrites only the `mission`
file … leaving the rest of `src/mission/` untouched"*. The action mutates
`mission.warehouses_content` and calls `save_folder_mission`, which never writes that table. An
airfield's coalition lives in `warehouses`, so the only thing the action exists to do was the one
thing that could not reach the disk.

It is a fail-silent on an action that **promises** durability in its return value, which is worse
than an error: the caller is told it worked.

## The change

`write_mission_folder` also writes the `warehouses` table — but **only when the folder already has a
`warehouses` file**, so it never invents a member the mission did not carry. `read_mission_folder`
has always read it; this closes the round trip.

## Tests

Three, in `test_miz_tools.py`: a changed warehouses table survives a write/read round trip; the
mission table is still written (the existing behaviour is not traded away); and a folder with no
`warehouses` file still writes its mission, without creating one.
