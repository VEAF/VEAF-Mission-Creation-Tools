# 03 — An action that creates a player slot

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/actions.py` and its group writer, the mission-maker
action catalogue (both languages), tests

## The need

A mission maker will need this for certain, and until it exists an assistant cannot produce a mission
anybody can fly. Writing one by hand is not a workaround: a plane group carries payload, radio,
callsign, onboard number, parking, and a first waypoint whose `type` and `action` are a **pair** — a
missing field makes DCS refuse the mission.

## What it does, and what it deliberately does not

An action creating an aircraft group whose units carry `skill: "Client"`, with:

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

## TDD

- A created slot has `skill: "Client"` and shows up in `describe_units`.
- Cold and hot write the right `type`/`action` pair — both asserted, since writing one without the
  other is the silent failure here.
- A ground start with no parking spot is refused, with a message naming ticket 09's data.
- Its country lands in `coalitions.<side>` as well, exercising ticket 01's writer from this path.

## Acceptance criteria

- [ ] The action ships, documented in the catalogue in both languages.
- [ ] A mission built from `scaffold_mission` + this action + `build_mission` is flyable.
- [ ] Full Python gate green; coverage ratchet respected.
