# FIX-MCP-SESSION-PREP-FINDINGS — what preparing an in-game test through the MCP broke

Status: ✅ done — 2026-10-10 (PR #1116) · archived 2026-11-24

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
| [01](FIX-MCP-SESSION-PREP-FINDINGS.md) | `loadout_from` copies a loadout whose stations run 1 to n | ✅ |
| [02](FIX-MCP-SESSION-PREP-FINDINGS.md) | A group or unit name already in the mission is refused | ✅ |
| [03](FIX-MCP-SESSION-PREP-FINDINGS.md) | `remove_group` refuses an ambiguous name and takes `group_id` | ✅ |
| [04](FIX-MCP-SESSION-PREP-FINDINGS.md) | Vendor CTLD `2.0.0-rc13` | ✅ |

## Definition of done

- Each defect has a test that failed before its fix.
- `vendored.yaml` pins CTLD `2.0.0-rc13`, the file is the release asset in LF, the Lua suite is green.
- The MCP developer page (FR + EN) and the action descriptions say what changed.
- `CHANGELOG.md` under `[Unreleased]`; no version bump.

## Tickets, in full

## 01 — `loadout_from` copies a loadout whose stations run 1 to n

Status: ✅ done

`normalize_pylons` iterated `pylons.items()`; a loadout read from a mission group with stations 1..n and no gap comes back from the Lua parser as a list.

- A list is read as stations from 1, in order (`aircraft_payload.normalize_pylons`).
- Tests: the function on a list and on a dict; `create_qra` with `loadout_from` a group whose pylons are `[1]` and `[2]`.

## 02 — A group or unit name already in the mission is refused

Status: ✅ done

`mission_tools.group_insertion.add_group`, which every MCP action creating a group goes through, appended whatever it was given — documented as "not deduplicated, like two clicks in the Mission Editor", which is wrong twice: the editor renames a copy, and DCS resolves either of two homonyms by name.

- The insertion refuses a group name, or a unit name, the mission already holds (any coalition, any category), naming what holds it; nothing is written.
- Tests: the two "calling twice creates two groups" tests become refusals; a unit-name clash; a mission whose groups read back as a dict table; `add_air_group` twice with one name, the session's case.
- Doc: the `add_group` bullet of the MCP page (FR + EN), the `add_group` action description and module docstring.

## 03 — `remove_group` refuses an ambiguous name and takes `group_id`

Status: ✅ done

`remove_group` located the first group of the name, then filtered the container by name: every homonym went, one was reported.

- Several groups of the name and no `group_id`: refused, listing each `groupId` with its coalition and category; nothing written.
- `group_id` given: only that group goes, by identity, its homonym stays; a `group_id` not carrying the name is refused.
- Needed even with ticket 02: a mission written before it may already hold homonyms, and this is how they are cleaned.
- Doc: the `remove_group` section of the MCP page (FR + EN) and the action's schema.

## 04 — Vendor CTLD `2.0.0-rc13`

Status: ✅ done

`published-v2.0.0-rc13`, 2026-10-09: crates, vehicles, JTACs, troops and beacons created under the requesting aircraft's country or a country of its coalition (VEAF/CTLD#256) — what *Kolkhida* needs, flown under CJTF Blue and CJTF Red ([`FIX-CAMPAIGN-MISSION-1-FINDINGS`](../FIX-CAMPAIGN-MISSION-1-FINDINGS/PRD.md) ticket 05); the F10 menu rebuilt entry by entry; crates placed where the native cargo window loads them.

**Breaking changes, checked against this repository**: the zone accessors and zone events now name a zone by its full name. VMCT calls `registerFOBAsLogistic`, `registerFOBAsTroopZone`, `activateLogisticZone`, `deactivateLogisticZone`, `setTroopZoneActive` and `unregister*` with the names it registered itself (`AB_<airbase>`, the FOB's name), and reads no zone event; `activatePickupZone`, `changeRemainingGroupsForPickupZone` and the `On*Zone*` events appear nowhere outside the backlog.

- `src/scripts/community/CTLD.lua` is the release asset, line endings normalised to LF; `ctld.VERSION` reads `2.0.0-rc13`.
- `vendored.yaml` pins `2.0.0-rc13` and watches `published-v2.0.0-rc13`.
- `poetry run test-lua`: 57 suites green, the community load gate included.

Not claimed: flown in DCS from this repository. The R47 check of 2026-10-10 is built with it.
