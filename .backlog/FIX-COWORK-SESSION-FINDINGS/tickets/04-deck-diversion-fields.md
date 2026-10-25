# 04 — The deck's diversion fields

Status: ✅ done

The deck said "Diversion fields: Senaki", Senaki being the departure, while the assistant's own briefing named Kutaisi as the divert.
`mission_briefing_worker.py` builds the line from every airfield and carrier of the mission picture, the departure included, and `build_mission_briefing` has no parameter to set it.

Leave the departure fields (those carrying the players' slots) out of the computed list, and accept a `diversions` list of airfield names that replaces it, resolved against the theatre like `set_airbase_coalition`.

Done when: a mission departing from one field lists only the others; `diversions: ["Kutaisi"]` prints Kutaisi; an unknown name is refused with the list; tests; the objective prompt mentions the parameter.

## Result

Fix: the departure fields (and a departure carrier) are left out of the computed list; `build_mission_briefing` takes `diversions`, checked against `list_airfields` and spelt as DCS spells them, an unknown name refused. The objective prompt mentions it.
Tests: `TestDiversionFields`, `test_diversions_are_spelt_as_dcs_and_an_unknown_one_is_refused`.
