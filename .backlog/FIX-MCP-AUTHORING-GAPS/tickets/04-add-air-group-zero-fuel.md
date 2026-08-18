# 04 — `add_air_group` creates aircraft with an empty fuel tank

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_air_group.py` (and `player_slot.py`, same payload
builder), tests

## What happens

`add_air_group` writes `payload = { chaff = 0, flare = 0, fuel = 0, gun = 100, pylons = {} }`.
`fuel = 0` means **no fuel at all**.

Measured on 2026-08-18, `verify-mission-c`: a KC-135 and its two F-15C escorts created by
`add_air_group` at 20 000 ft pitched straight into the ground the instant they appeared — engines
out. David's report and screenshot: *"ils piquent vers le sol dès leur apparition"*, the tanker at
-49° of pitch seconds after spawning.

Every VEAF template in the same mission carries the airframe's own capacity — `F-15C: 6103`,
`F-14B: 7348` — so the mission file itself shows what the value should look like.

## Why it is worth a ticket rather than a workaround

It cost two rounds of a DCS verification session, and it cost them **twice**: the first time the
crash was attributed to the SAM battery the tanker was parked next to, the second time it was still
unexplained and left issue #101 inconclusive. A defect that makes an unrelated check fail is worse
than one that fails loudly, because it gets attributed to whatever the check was about.

An air start is the default for `add_air_group` (`start: "air"`), so this is the default path, not an
edge case. A ground start hides it: DCS fuels a parked aircraft from the airfield's stock, which is
why the parked player slots never showed the problem.

## What ships

- A sensible default fuel load. **Full internal fuel** is the honest default for a spawned aircraft,
  and it is what the templates do. The per-type capacity has to come from somewhere: `dcsUnits.lua`
  ships a unit database — check whether it carries the value before inventing a table.
- An optional `fuel` parameter (kg, or a fraction of capacity) for a caller who wants something else.
- Same treatment for `add_player_slot`, which builds its payload the same way. It matters less there
  — a parked slot is fuelled by the airfield — but an air-start player slot has exactly this bug.

## Done when

- An aircraft created by `add_air_group` with an air start has fuel and flies
- The value comes from the shipped unit database rather than a hand-written table, or the reason it
  cannot is written here
- A test asserts a non-zero fuel load for an air start, per category (plane, helicopter)
