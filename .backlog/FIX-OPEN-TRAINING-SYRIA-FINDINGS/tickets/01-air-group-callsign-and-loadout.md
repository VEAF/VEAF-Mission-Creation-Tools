# 01 — add_air_group: callsign from the group name, no armed task without a loadout

Status: ✅ done

Files: `veaf_mission_mcp/aircraft_identity.py`, `veaf_mission_mcp/add_air_group.py`, `veaf_mission_mcp/actions.py`
(description), tests.

## What happened

- Callsign. `assign_identities` gives a western flight "the first family (for the task) that no aircraft of
  the mission uses yet" (`_free_family_and_flight`); the group name is never read. The Open Training prompt
  asks for « nom de groupe = indicatif ». Built in this order — Texaco 1, Arco 1, Texaco 2, Arco 2 — the
  third tanker became `Shell11` and the fourth `Texaco21`. Texaco 1, Arco 1 and Magic 1 were right only by
  the order they were created in.
- Loadout. Eight escort pairs (`task: Escort`, F-15C and Su-30) were created with an empty `pylons` table
  and no warning. They escort nothing.

## Done when

- A group name that starts with a family word of its task and a flight digit (`Texaco 2`, `Magic 1`) gets
  that family and flight, numbered 1, 2…, the name written as the editor writes it (`Texaco21`). A word that
  is not a family of the task, or a flight another group already holds, falls back to today's rule, and the
  result says which.
- A flight whose task fights (`Escort`, `CAP`, `Intercept`, `Fighter Sweep`, `CAS`, `Ground Attack`, `SEAD`,
  `Antiship Strike`, `Pinpoint Strike`, `Runway Attack`) created with no `pylons` gets a warning naming the
  group. Not a refusal: a Client slot is legitimately empty.
- Tests: the four tankers above give Texaco11, Arco11, Texaco21, Arco21; an unarmed Escort warns.
