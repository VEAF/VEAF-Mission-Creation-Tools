# 06 — Accents lost in what the AI writes

Status: ✅ done

Measured, 2026-10-22, on Martinho's export and mission folder (6.31.4), and on David's sandbox export (6.31.2): the model writes accented French through `write` and `edit` (README, comments of `waypoints.yaml`) and **unaccented** French inside the JavaScript it passes to `execute` — `set_briefing` (`colonne blindee`, `noeud logistique`, `Detruire`), `build_mission_briefing`, `create_combat_zone` (`friendly_name`, `briefing` in `mission.yaml`). Its own reasoning, drafted a step earlier, had the accents.
The tools are not the cause: `set_briefing` called by hand with `é`, `œ`, `É` stores them intact in `src/mission/mission`, and no code on the path normalises to ASCII.
The one place the guide asks for ASCII is the mission's *name* (`VEAF_<Map>_<Title>`, title without accents); the model probably carried it over to all its text.

Fix, in the two places that can act:

- The guide and the objective prompt (FR, EN): what a player or a mission maker reads — briefing, objectives, zone titles, threats, notes — is written in its language **with its accents**, also inside a tool call; only identifiers (mission name, zone and group names, callsigns) stay ASCII.
- A warning, never a refusal: `set_briefing`, `build_mission_briefing` and `create_combat_zone` say so when a French text of some length carries no accented letter while it uses common French words that take one.

Done when: the guide and the prompt say it, the warning is tested both ways (an unaccented French text warns; an accented one, an English one and a short one do not), and the warning names the text and the fix.

## Result

Fix: `veaf_mission_mcp/accents.py` (`missing_accents_warning`) judges a text of some length with no accented letter that uses two different French words that take one (a list of unambiguous unaccented spellings, no word that is also English); `set_briefing`, `build_mission_briefing`, `create_combat_zone` and `add_combat_operation` return the warning, never refuse. The guide and the objective prompt (FR, EN) say what a player reads keeps its accents, also inside a tool call. Tests: the helper both ways, and each action.
