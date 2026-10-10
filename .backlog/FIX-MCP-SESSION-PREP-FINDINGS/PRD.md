# FIX-MCP-SESSION-PREP-FINDINGS — what preparing an in-game test through the MCP broke

Status: ✅ done — 2026-10-10 (PR #1116)

## Found

Claude, 2026-10-10, preparing the in-game test of *Kolkhida* mission 1 (R47 of `DCS-SESSION-TODO.md`) on a copy of the campaign, through the `veaf-mission-mcp` server: putting the Senaki QRA on the runway with `create_qra`, then adding the test slots with `add_air_group` and `remove_group`.

Each defect was reproduced outside DCS, by calling the action on a copy of mission 1's folder:

1. `create_qra` with `loadout_from: "QRA Senaki MiG-29"` fails with `AttributeError: 'list' object has no attribute 'items'` in `normalize_pylons`. The source group's pylons are numbered 1 to 7 with no gap, and the Lua parser hands such a table back as a list. The shipped test passed because its template had a single pylon, `[2]`, which reads back as a dict.
2. `add_air_group` called twice with the name `TEST A-10C air` wrote two groups of that name. DCS does not refuse homonyms, it resolves one of them by name, silently — the trap `FIX-DUPLICATE-UNIT-NAMES` met at runtime.
3. `remove_group` on that name then removed **both** groups and reported one (`group_id: 16`). The mission was built without the slot, and only the check of the built `.miz` showed it.

Also found the same day, and **not** defects: `campaign next` refreshing mission 1's folder kept its hand-written `waypoints.yaml` (no fingerprint) and its `follow: players` (a value designed in the folder) — both by design; and the backup of `src/mission/mission` that was thought missing exists, named `mission.<stamp>` with no extension.

And taken in the same lot: CTLD `2.0.0-rc13`, released 2026-10-09, carrying VEAF/CTLD#256 (crates under a country of the coalition) that *Kolkhida* mission 2 needs on 2026-10-15.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-loadout-from-stations-one-to-n.md) | `loadout_from` copies a loadout whose stations run 1 to n | ✅ |
| [02](tickets/02-a-taken-name-is-refused.md) | A group or unit name already in the mission is refused | ✅ |
| [03](tickets/03-remove-group-homonyms.md) | `remove_group` refuses an ambiguous name and takes `group_id` | ✅ |
| [04](tickets/04-vendor-ctld-rc13.md) | Vendor CTLD `2.0.0-rc13` | ✅ |

## Definition of done

- Each defect has a test that failed before its fix.
- `vendored.yaml` pins CTLD `2.0.0-rc13`, the file is the release asset in LF, the Lua suite is green.
- The MCP developer page (FR + EN) and the action descriptions say what changed.
- `CHANGELOG.md` under `[Unreleased]`; no version bump.
