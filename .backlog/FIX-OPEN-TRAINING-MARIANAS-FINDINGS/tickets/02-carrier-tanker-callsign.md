# 02 — add_carrier_group: the recovery tanker leaves the tanker families to the tankers

Status: ✅ done

Files: `veaf_mission_mcp/carrier.py` (recovery tanker, built with task `Refueling`), `veaf_mission_mcp/aircraft_identity.py`, tests.

## What happened

`add_carrier_group` builds `<carrier> S3B-Tanker` with task `Refueling`; its name starts with no family word, so the identity rule gives it the first free tanker family.
Two carriers placed first took `Texaco11` and `Arco11`; the four tankers created afterwards, named `Texaco 1`, `Arco 1`, `Texaco 2`, `Arco 2`, then each got another family, with a warning (`Shell11`, `Texaco21`, `Arco21`, `Shell21`).
The Open Training prompt places the carriers before the tankers (4.3), so every Open Training meets it.
Worked around with `set_unit_properties` (S-3B to `Shell51` / `Shell61`, then each tanker on its name).

## Done when

- A recovery tanker takes a callsign that a tanker named `Texaco n` / `Arco n` / `Shell n` will not claim later — for instance the `Shell` family from flight 9 down — and the result says which.
- Or `add_carrier_group` takes `tanker_callsign` (word + flight), defaulting to that rule.
- Tests: two carriers then the four tankers above give Texaco11, Arco11, Texaco21, Arco21 to the tankers.

## Done

Both (David, 2026-10-12): by default the recovery tanker takes `Shell` from flight 9 down (`aircraft_identity.recovery_tanker_callsign`), and `add_carrier_group` takes `tanker_callsign` (a tanker family and a flight, refused when it is not one or is held). The result's `tanker_callsign` says which. Ignored for a country with numeric callsigns.
