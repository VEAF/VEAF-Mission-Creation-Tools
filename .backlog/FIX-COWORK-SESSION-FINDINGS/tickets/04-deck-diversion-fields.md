# 04 — The deck's diversion fields

Status: ⬜ ready

The deck said "Diversion fields: Senaki", Senaki being the departure, while the assistant's own briefing named Kutaisi as the divert.
`mission_briefing_worker.py` builds the line from every airfield and carrier of the mission picture, the departure included, and `build_mission_briefing` has no parameter to set it.

Leave the departure fields (those carrying the players' slots) out of the computed list, and accept a `diversions` list of airfield names that replaces it, resolved against the theatre like `set_airbase_coalition`.

Done when: a mission departing from one field lists only the others; `diversions: ["Kutaisi"]` prints Kutaisi; an unknown name is refused with the list; tests; the objective prompt mentions the parameter.
