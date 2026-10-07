# FEAT-CAMPAIGN-MISSION-BRIEFING — each campaign mission gets its own briefing, and a date, a time and a weather of its own

Status: 🧑 waiting-human

David, 2026-10-07, the evening before the first mission of *Kolkhida* flown by the squadron: "y'a pas de doc de briefing spécifique à chaque mission ? que le briefing de campagne ?".
The campaign briefing ([`FEAT-CAMPAIGN-BRIEFING-DECK`](../FEAT-CAMPAIGN-BRIEFING-DECK/PRD.md)) has one page for the coming mission; the VEAF mission briefing — the one the objective-mission prompt produces (`.prompts/new-objective-mission.fr.md` §3 and §6) — had no equivalent for a campaign mission. Answer "a puis b": a prototype for the next day's flight, then this lot.

The prototype is in [`prototype/make_mission_briefing.py`](prototype/make_mission_briefing.py): about 470 lines, it read the campaign, `briefing.yaml` and the **built** `.miz`, and wrote an 11-page `briefing-mission.pptx` with a tactical map and one zoom per objective.

The same evening David set how a campaign mission's date, time and weather are chosen; they belong to the same lot because the briefing states them.

## What David asked

| # | David | What it means |
|---|---|---|
| 1 | "y'a pas de doc de briefing spécifique à chaque mission ?" | a mission briefing next to the campaign one, after the VEAF mission briefing template |
| 2 | "ne crée pas de variantes, juste celle là" | one mission, no weather variants: `pipeline.weather: false`, no `src/versions.yaml` |
| 3 | "la date et l'heure, ainsi que la météo des missions doit être fixée. On peut randomiser le vent, la pluie et les nuages en fonction des missions (mais il faut qu'on voie le sol, donc CAVOK ou presque)" | fixed date, time and weather in each mission; the weather may change from one mission to the next, within ground-visible limits |
| 4 | "c'est à toi de fixer la date et l'heure en fonction de l'avancée de la campagne" — "et pas juste ici, de manière générale quand tu prépares des missions d'une campagne" | the date moves on with the campaign; the time serves the mission (Kolkhida 1: just after dawn) |

## The mission briefing — what the prototype made, and what it could not

Pages, after the VEAF template (16:9, white, bold title top left, Calibri):

1. **Cover** — operation and mission number, the mission's title, date and time.
2. **Situation générale** — context (mission statement and the phase of the concept), mission (the tasks' titles), bullseye (DMS, bearing and range from a friendly base), departures (carrier deck, airfields with dynamic slots), threat (the intelligence of ticket 02 of the briefing deck lot, plus a QRA zone when the mission has one), weather and time **read from the built mission**.
3. **ATO** — the client flights (callsign, type, count, base, pilot lines, "armement libre"), the airfields offering dynamic slots, the support (AWACS, tankers, the carrier's S-3B) with frequency and TACAN, the control (carrier tower, airfields UHF/VHF/TACAN).
4. **Situation tactique** — zones, axes, QRA zone, carrier, AWACS orbit, tanker track, bullseye, scale in nm.
5. **One zoom per objective** — the zone at its radius, its intelligence, its task.
6. **Déroulement mission** — main objectives, air opposition, air defences, other information (refuelling, diversion fields, rescue).
7. **Plan de fréquences** — UHF then VHF, guard first.
8. **Coordonnées des objectifs** — each objective zone's centre, DMS, and its ground elevation when a terrain grid has been swept.

What a campaign mission **cannot** have: target coordinates and a flight plan. A garrison is drawn when the mission starts, so no unit's position is known when the briefing is written; the briefing says so ("les positions exactes se relèvent en vol").

What the prototype got wrong first, and the tool must not:

- **Dynamic-slot templates are not flights**: 70 "… Template" groups came out in the ATO; they carry `dynSpawnTemplate = true`.
- **A support aircraft listed twice** (the carrier's S-3B as support and as deck tanker).
- **The carrier tower is VHF** (127.5 MHz), not UHF.
- **DMS rounding**: `08'60.00"` — round once to the hundredth of a second, then split.
- **Labels on top of each other** (the QRA zone's, the bullseye's, a zone's) — de-clutter as FEAT-BRIEFING-MAP plans to.
- **No terrain grid on the workstation**: say nothing rather than "altitude inconnue"; `terrain-sweep` makes one in minutes with DCS running.

## Date, time and weather of a campaign mission

- **Fixed in the mission**, one variant: the mission folder `campaign next` creates has `pipeline.weather: false` and no `src/versions.yaml`; date and time are set like `set_mission_date`, weather like `set_weather`.
- **The date moves on**: mission N+1 comes after mission N — the campaign keeps the date of the last mission and advances it (the next day by default; Claude may choose more).
- **The time serves the mission**, and a solar time is computed for the theatre's ground and the mission's date, not taken from the defaults: the shipped `versions.yaml` positions solar times at Damascus (`33.5, 35.5`), which made "sunrise" wrong on the Caucasus. Kolkhida 1: 2016-06-01, sunrise 05:39 at Kobuleti, start 06:09.
- **The weather may change, the ground stays visible**: wind, rain and clouds drawn per mission within limits — few or scattered clouds at most, visibility of 8 km or more, no fog — CAVOK or nearly.
- The deck and the DCS briefing state them.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-date-time-weather.md) | A campaign mission's date, time and weather, fixed and moving on | ✅ |
| [02](tickets/02-mission-picture.md) | What the built mission says: flights, support, carrier, QRA, airfields | ✅ |
| [03](tickets/03-tactical-maps.md) | The tactical map and one zoom per objective | ✅ |
| [04](tickets/04-mission-deck.md) | The mission briefing deck, from `campaign next` and `campaign briefing` | ✅ |
| [05](tickets/05-doc.md) | Documentation, and Claude's instructions | ✅ |

## What is left

Everything is built and tested off DCS. What waits for David: reading a mission briefing the tools generated — the next one being Kolkhida mission 2, after `campaign apply` and `campaign next` — against the prototype's, and saying what the squadron missed in it.

## Related

- [`FEAT-CAMPAIGN-BRIEFING-DECK`](../FEAT-CAMPAIGN-BRIEFING-DECK/PRD.md) (🧑): the campaign briefing; its deck helpers, intelligence and map base are reused.
- [`FEAT-BRIEFING-MAP`](../FEAT-BRIEFING-MAP/PRD.md) (⏸): label de-cluttering for mission maps; ticket 03 needed it and put it in `veaf_libs/map_labels.py` (`LabelPlacer`) for that lot to reuse.
- Found the same evening, outside this lot: the MCP declared in `~/.claude.json` runs from the main checkout, and a stale pre-generated `veaf_modules_list.json` there hid the `CAMPAIGN` module from `validate_mission` — the pre-generated list wins over the live scan in development.
