# DCS checks — FIX-OPEN-TRAINING-NORMANDY-FINDINGS

What the lot changed and could not be run in DCS here. Done on 2026-10-13 and removed from the table: ticket 15 (see its file: not a defect) ticket 14's three checks (`country germany` spawns red as `cjtf red` with the warning, `country thirdreich` spawns without one, a side with no Skynet network spawns with the `no default Skynet network` warning and no `networkName nil` error) and ticket 05's six aliases (each spawns its radar or battery on the red side, country CJTF Red, with the spawn data of the branch).
Run them on the Normandy test mission (LOCAL_TEST build, `--dev-mode` so it reads the built `veaf-scripts.lua`), one at a time; the answer is in the last column.
`dcs.log` is `C:\Users\David\Saved Games\DCS\Logs\dcs.log`.

| # | Ticket | Do | Expect | If not |
|---|---|---|---|---|
| F | 07 | Take a slot from the `FW-190A8 Template` (then `Bf-109K4`, `TF-51D`): loadout screen, then fire a burst | cannon ammunition shown and fired | zero: set `gun: 100` on the ten templates (known limitation `ww2-slot-templates-carry-gun-zero`) |
| G | 13 | Open the built mission in the Mission Editor and save it | saves without `Invalid frequency` | |
