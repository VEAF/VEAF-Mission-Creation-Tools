# 03 — An action that creates a player slot

Status: ✅ done 2026-08-15 — add_player_slot ships; dynSpawnTemplate fix confirmed in game
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/actions.py` and its group writer, the mission-maker
action catalogue (both languages), tests

## The need

A mission maker will need this for certain, and until it exists an assistant cannot produce a mission
anybody can fly. Writing one by hand is not a workaround: a plane group carries payload, radio,
callsign, onboard number, parking, and a first waypoint whose `type` and `action` are a **pair** — a
missing field makes DCS refuse the mission.

## What it does, and what it deliberately does not

An action creating an aircraft group whose units carry `skill: "Client"` and whose group carries
`dynSpawnTemplate = false` (see the measurement below — the missing flag is what broke the 2026-08-14
slot), with:

- **an air start** — position, altitude, speed, heading. Needs no runtime data at all.
- **a ground start when the caller supplies a parking spot.** This action does **not** resolve airfield
  parking: that is `FEAT-MCP-MUTATION-ACTIONS` ticket 09's data and it is not captured yet. Refuse a
  ground start with no spot rather than guessing one, and name that ticket in the refusal.
- `TakeOffParking` vs `TakeOffParkingHot` as an explicit cold/hot choice, written as the `type`/`action`
  **pair** DCS stores.

It does **not** change an existing unit's skill. `set_unit_properties` refuses that on purpose, and
this action must not become a back door to it.

## Measured, not invented

Read a real player group out of `test/veaf-tools/demo-mission/veaf-demo-mission.miz` before writing the
writer. `A-10C Kobuleti  HOT` is an `A-10C_2`, `skill: Client`, `parking: "43"`, and its first waypoint
is `TakeOffParkingHot` / `From Parking Area Hot`. The cold pair is `TakeOffParking` /
`From Parking Area`, verified by making exactly that edit on 2026-08-14 and loading the result.

### `dynSpawnTemplate` is what made the 2026-08-14 slot unusable — verified in game 2026-08-15

A slot created by this action **must carry `dynSpawnTemplate = false`**, and that single field is the
whole lesson of the 2026-08-14 defect.

**Confirmed by flying it**: the same mission with the flag cleared gives a slot David can take
(*"le A-10 fonctionne"*, 2026-08-15). So this is a measured fix rather than a hypothesis, and the
assertions below are writing down a known-good shape.

The slot placed that day was copied out of the demo mission — including its `dynSpawnTemplate = true`.
That flag does not describe a slot: it marks the group as a **template for dynamic spawn**, which
requires an airfield configured for it. This mission configures none, so the group was in the file,
absent from the slot list, and David stayed a spectator. He had in fact said so on day one — *"il n'y
a que des templates de groupe, et pas de base aérienne configurée pour les slots dyn"* — and the
build had 105 groups carrying the flag.

The differential against the A-10 he added in the editor, and against the demo's original:

| | script (ko) | editor (ok) |
|---|---|---|
| `dynSpawnTemplate` | **`true`** | **`false`** |
| `communication` / `frequency` | `false` / 121.5 | `true` / 251 |
| `skill` | `Client` | `Player` |
| ids | 9001 | 9003 |
| parking | `43` / `16`, `airdromeId` 24 | `6` / `01`, `airdromeId` 22 |
| first waypoint | `TakeOffParking` | `TakeOffParking` — identical |

**`skill` is not the cause**: David, 2026-08-15 — *"c'est pas le slot Client ; ça fonctionne dans une
mission DCS"*. `Client` stays what this action writes. The forced ids are cleared too (the editor
writes 900x itself), as is the parking pair, complete on both sides.

`communication = false` is a second, milder defect of the same copy: both working A-10s carry `true`
with a real frequency. A created slot gets a group frequency rather than an inherited `false`.

## TDD

- A created slot has `skill: "Client"`, `dynSpawnTemplate = false` and a group frequency — the three
  assertions that would have caught the 2026-08-14 defect. It shows up in `describe_units`.
- Copying a group out of a mission does **not** carry `dynSpawnTemplate = true` over into a slot. That
  is the exact path the defect took.
- Cold and hot write the right `type`/`action` pair — both asserted, since writing one without the
  other is the silent failure here.
- A ground start with no parking spot is refused, with a message naming ticket 09's data.
- Its country lands in `coalitions.<side>` as well, exercising ticket 01's writer from this path.

## Acceptance criteria

- [x] The action ships (`add_player_slot`), documented in the mission-maker catalogue and the
      developer reference, both languages.
- [~] A mission built from `scaffold_mission` + this action + `build_mission` is flyable — the pieces
      are unit-tested (Client skill, `dynSpawnTemplate` false, group frequency, waypoint pairs,
      coalitions populated); flying it is David's in-game step, and the `dynSpawnTemplate` fix is
      already confirmed in game (2026-08-15).
- [x] Full Python gate green; coverage ratchet respected.
