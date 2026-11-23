# 08 — Intelligence: hidden garrisons, reconnaissance, spy team

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

Analysis note 06 §5 and note 07 §10 (spy team only; the demolition team is V1.5).

- For the players' side, an enemy zone's label shows its name and "strength unknown" until it is **revealed**; the enemy side sees its own zones in full.
  So the zone labels are drawn per coalition, not for all.
- A zone is revealed for `intel.seconds` (3 600 s) by:
  - an overflight: a player aircraft of the side within the zone's radius, under `intel.overflight_altitude` (1 500 m above ground) — the beat checks the awake zones only;
  - a JTAC drone bought over it (ticket 06);
  - the Intel item of the shop;
  - a spy team.
- A revealed zone shows its strength on the map, and Campaign → Intel gives its composition (unit types and counts, air defence first).
- **Spy team**: a CTLD 2 troop group whose template is `intel.spy_troops` ("Spy") deployed within `intel.spy_range` (5 km) of an enemy zone walks into it; on arrival the zone is revealed for an hour and the side is told. No enemy zone in range: the side is told and the team stays.
  The persistent example mission declares that one-man troop group in its `ctld-config.yaml`.
- Reveals survive a restart (remaining seconds saved).

## Done when

Lua tests: hidden label for the other side, reveal by each channel, expiry, composition text, spy routed to the nearest zone in range and revealing on arrival.
In game: an enemy zone's label reads "strength unknown"; after an overflight it reads its strength.
