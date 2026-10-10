# 04 — Vendor CTLD `2.0.0-rc13`

Status: ✅ done

`published-v2.0.0-rc13`, 2026-10-09: crates, vehicles, JTACs, troops and beacons created under the requesting aircraft's country or a country of its coalition (VEAF/CTLD#256) — what *Kolkhida* needs, flown under CJTF Blue and CJTF Red ([`FIX-CAMPAIGN-MISSION-1-FINDINGS`](../../FIX-CAMPAIGN-MISSION-1-FINDINGS/PRD.md) ticket 05); the F10 menu rebuilt entry by entry; crates placed where the native cargo window loads them.

**Breaking changes, checked against this repository**: the zone accessors and zone events now name a zone by its full name. VMCT calls `registerFOBAsLogistic`, `registerFOBAsTroopZone`, `activateLogisticZone`, `deactivateLogisticZone`, `setTroopZoneActive` and `unregister*` with the names it registered itself (`AB_<airbase>`, the FOB's name), and reads no zone event; `activatePickupZone`, `changeRemainingGroupsForPickupZone` and the `On*Zone*` events appear nowhere outside the backlog.

- `src/scripts/community/CTLD.lua` is the release asset, line endings normalised to LF; `ctld.VERSION` reads `2.0.0-rc13`.
- `vendored.yaml` pins `2.0.0-rc13` and watches `published-v2.0.0-rc13`.
- `poetry run test-lua`: 57 suites green, the community load gate included.

Not claimed: flown in DCS from this repository. The R47 check of 2026-10-10 is built with it.
