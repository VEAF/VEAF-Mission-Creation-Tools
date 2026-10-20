# 03 — The reference data an AI needs before a mission folder exists

Status: ⬜ ready

The export lists what the AI read from the exe's own files instead of an action (PRD, finding 3).
For each, first check whether an action already answers it and the guide or the prompt fails to point to it; add an action only where none does:

- DCS country ids by name;
- parking capacity per airfield of a theatre;
- the ATC frequencies of a theatre's airfields, with no mission;
- whether a type can be placed as a static;
- the shipped dynamic-slot templates (type, frequency);
- lat/lon ↔ x/y for a theatre with no mission folder (`resolve_coordinates`, `geocode` and `terrain_elevation` took a `mission_path`);
- the `combat_zones` keys of `mission.yaml`.

Done when: each item is answered by an action an AI finds from the guide, tested; the prompts' phase 1 (read-only, before the scaffold) can be done without a folder.
