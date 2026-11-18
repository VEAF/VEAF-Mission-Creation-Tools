# 03 — recon-shoot: one zone at a time, DCS's own screenshot, positions read at the grab

Status: 🔄 in progress

- For a shot on a combat zone: every active zone is deactivated, the shot's zone activated alone, its spawn awaited, and the zone deactivated after the shot.
- The shot's units are the ones the zone reports (spawned groups and its elements' groups), not a name prefix; `groups` narrows them when given.
- The camera is placed and left for `--warmup` seconds (10 by default) so the terrain loads; positions are read again and the camera re-placed; positions are read once more just before the grab, for the rings.
- The grab is DCS's own screenshot (`LoSetCommand(257)` in the export state), picked up in `Saved Games\DCS\Screenshots`; the window may stay in the background. `--capture window` keeps the old window grab.
