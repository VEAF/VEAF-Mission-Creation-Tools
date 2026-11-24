# FIX-DEMO-VIDEO-FINDINGS — what the AI worked around while building missions with the VEAF tools

Status: ✅ done · archived 2026-11-24

Two origins, both a free model (DeepSeek V4.1 Flash on OpenCode) building an objective mission from a clean Windows machine:

- **David's demo video, 2026-10-22** (VMCT 6.31.3, GermanyCW, "Cut the Werra Bridge"). In its final report the AI listed what the tools made it work around. Tickets 01–05 are its words, read off the video (around 5:06).
- **Martinho's session, 2026-10-22** (VMCT 6.31.4, SinaiMap, "Le carburant de la colonne"; the OpenCode export and his mission folder). David noticed that the briefing had no accents; reading the export and the folder turned up the rest. Tickets 06–14. A second run of the same kind (David's sandbox, Caucasus, 6.31.2) shows the same missing accents.

Each ticket measures first: a non-defect (DCS behaviour, a misuse the guide should prevent) is written down in its ticket with the measurement, and fixed in the guide or the known limitations instead of the code. A limitation is only recorded when nothing in the tools can lift it.

| # | What happened | Ticket |
|---|---|---|
| 1 | "the tools reject `Texaco` as a Tanker callsign family" — the KC-135 became `Enfield` | 01 |
| 2 | "the packer refuses 123.5 MHz for the UH-1H radio" — the Huey flight got 250.700 | 02 |
| 3 | "with dynamic slots the deck has no flight list" — a script filled the ATO page after every briefing | 03 |
| 4 | "Deck's Support line and tactical map only pick up the AWACS"; `inspect_built_mission` too | 04 |
| 5 | "`build_mission` overwrites the .miz and wipes briefing pictures" | 05 |
| 6 | The briefing, the zones' names and their briefings were written **without accents** (reasoning had them, the tool call did not) | 06 |
| 7 | The briefing and the F10 labels said NŒUD = W3, COLONNE = W4, OVDA = W6; the route had BULLSEYE third, so they were W4, W5, W7 | 07 |
| 8 | No PDF without PowerPoint: the AI improvised an Edge HTML print (video) or installed LibreOffice and failed (Martinho) | 08 |
| 9 | `read_mission_file` takes `file`, the AI passed `path` | 09 |
| 10 | `add_group` with the coalition `neutral`: a bare `KeyError`, no list of the valid ones | 10 |
| 11 | `validate_mission` warns that `waypoints.yaml` has no aircraft group to inject, with dynamic slots that receive it | 11 |
| 12 | "no clear-ground catalogue covers this place" read as "GermanyCW has no catalogue" — it covers 25 zones, not the AI's | 12 |
| 13 | `create_combat_zone` takes one category per call: thirteen `add_group` calls for the statics | 13 |
| 14 | `inspect_built_mission` shows neither the date nor the briefing pictures; the AI opened the `.miz` with a shell | 14 |

## Tickets

- [01 — "Texaco" refused for a tanker](FIX-DEMO-VIDEO-FINDINGS.md)
- [02 — 123.5 MHz refused on the UH-1H](FIX-DEMO-VIDEO-FINDINGS.md)
- [03 — The ATO page is empty with dynamic slots](FIX-DEMO-VIDEO-FINDINGS.md)
- [04 — Support: only the AWACS, the tanker forgotten](FIX-DEMO-VIDEO-FINDINGS.md)
- [05 — `build_mission` wipes the briefing pictures](FIX-DEMO-VIDEO-FINDINGS.md)
- [06 — Accents lost in what the AI writes](FIX-DEMO-VIDEO-FINDINGS.md)
- [07 — Waypoint numbers in the briefing do not match the route](FIX-DEMO-VIDEO-FINDINGS.md)
- [08 — A PDF of the briefing, from the executable](FIX-DEMO-VIDEO-FINDINGS.md)
- [09 — `read_mission_file` takes `path`](FIX-DEMO-VIDEO-FINDINGS.md)
- [10 — `add_group` and the coalition `neutral`](FIX-DEMO-VIDEO-FINDINGS.md)
- [11 — `validate_mission` and dynamic slots](FIX-DEMO-VIDEO-FINDINGS.md)
- [12 — The clear-ground message says what the catalogue covers](FIX-DEMO-VIDEO-FINDINGS.md)
- [13 — `create_combat_zone` takes statics and vehicles together](FIX-DEMO-VIDEO-FINDINGS.md)
- [14 — `inspect_built_mission` shows the date and the briefing pictures](FIX-DEMO-VIDEO-FINDINGS.md)

Out of this lot: widening the clear-ground catalogue itself, which needs a survey flown in DCS ([FEAT-CLEAR-GROUND-COVERAGE](../FEAT-CLEAR-GROUND-COVERAGE/PRD.md)).

## Tickets, in full

## 01 — "Texaco" refused for a tanker

Status: ✅ done

The AI: "the tools reject `Texaco` as a Tanker callsign family"; the KC-135 was named `Enfield` instead.
Texaco is DCS's first tanker callsign (Texaco = 1, Arco = 2, Shell = 3), and the authoring guide itself names it as the example.

Measure on GermanyCW: `add_air_group` (or the support composite the AI used) with a KC-135 named Texaco — what is refused, by which check, with which message.
Suspects: the callsign-family reading of `aircraft_identity.py` (a bare family word, or the family taken from the name), or a family list that differs for a tanker or for this map's country.

Done when: a KC-135 tanker named Texaco gets the Texaco family, with a test; or the refusal is shown to be right and the guide says what to do instead.

### Result

Measured (code and test): the AI called `add_air_group` with `task: "Tanker"`; DCS's group task for a tanker is `Refueling`, and the callsign families (`aircraft_identity._TASK_FAMILIES`) are keyed on it, so `Tanker` fell to the common families (Enfield…) and Texaco was refused as "not a family of the task". Same root as ticket 04.
Fix: `canonical_task` reads `Tanker` (also `refuel`, `refuelling`, `AEW&C`) as the DCS word, with a note in the result's warnings; `add_air_group` stores the canonical task. Tests: `TestTankerTaskAlias` (the task is stored `Refueling`, the callsign is Texaco, the canonical word says nothing).

## 02 — 123.5 MHz refused on the UH-1H

Status: ✅ done

The AI: "Huey is on UHF: the packer refuses 123.5 MHz for the UH-1H radio, so Blade got 250.700 on the package plan".
The UH-1H's ARC-51BX is UHF only (225–399.975 MHz); its VHF (ARC-134, 116–149.975 MHz) is not a preset radio. So refusing 123.5 on the preset radio may well be right.

Measure: what the preset packer accepts for the UH-1H, per radio, and what the refusal said to the AI.
If the refusal is right, the gap is the explanation: the AI should learn from the refusal (or from the guide) which band the Huey's preset radio takes, instead of discovering it by trial.

Done when: the measurement is written here; a wrong refusal is fixed with a test, a right one gets a message that names the radio and its band.

### Result

Measured: the UH-1H's only preset radio is its UHF AN/ARC-51, 225–399.975 MHz (`presets_injector/data/dcs-radio-specs.yaml`); its VHF AM/FM are not preset radios. The refusal is right, and the packer's message already lists the valid ranges ("Valid ranges: …"). The gap is upstream: the AI planned 123.5 MHz for a Huey flight.
Fix: the authoring guide says to pick a flight's channel inside the band of its aircraft's preset radio, the Huey's being UHF. No code change.

## 03 — The ATO page is empty with dynamic slots

Status: ✅ done

The AI: "ATO page is completed by script: with dynamic slots the deck has no flight list, so `tools/patch-ato.ps1` writes the four flights, aircraft and frequencies into it (re-run after every `build_mission_briefing`)".
The objective prompt says that with dynamic slots "the ATO keeps the callsigns with empty pilot boxes" — so the ATO is expected to list the flights, and `build_mission_briefing` apparently builds it only from groups with player slots.

The final deck (video, page 4) shows what the AI's script produced: one block per base ("Dynamic slots - Spangdahlem: A-10C II (Archer, 250.100) - AV-8B (Nickel, 250.300) - F-16C (Ninja, 250.500)"), four pilot boxes, "Free loadout".

Measure on a clean GermanyCW mission with dynamic slots only: what page 2 of `docs/briefing.pptx` holds.
Fix: the ATO of a dynamic-slot mission lists its flights — from the dynamic-slot templates, their callsigns and frequencies, and the bases offering them — with empty pilot boxes, so no AI has to patch the deck.

Done when: a dynamic-slot mission's ATO page lists its flights, with a test on the built deck.

### Result

Fix: `mission_reader.slot_flights` reads, for each base of the side that offers dynamic slots, the types linked to one of its templates (`linkDynTempl` of the warehouse entry) and, for each, the first named channel of its first radio (`A-10C_2 — Archer : 390.0 MHz`); `ato_page` lists them under the airfield's "dynamic slots" line, before the empty pilot boxes. Tests: `TestDynamicSlotAto` (a linked template is listed with its channel; a base linking none lists no type).

## 04 — Support: only the AWACS, the tanker forgotten

Status: ✅ done

The AI: "Deck's Support line and tactical map only pick up the AWACS (builder limitation); the tanker is in the mission and correct", and "`inspect_built_mission` "support" lists only Overlord; the Enfield tanker is correctly present in the .miz (Tanker task, TACAN 63Y, 262 MHz, orbit, unlimited fuel)".
Its own script then wrote both on the ATO page ("Overlord 1-1 - AWACS, E-3A: 255.0 MHz - Enfield - Tanker, KC-135: 262.0 MHz (TACAN 63Y)").

Two readers miss the same group, so the cause is probably one shared reading of "support": a tanker recognised by something the AI's group did not carry (its callsign family, see ticket 01; its name; the task on the group rather than the route), or a reader that keeps the first support group only.

Measure on a clean mission with an AWACS and a tanker added through the actions: what `inspect_built_mission`, the deck's Support line and its tactical map report.

Done when: both report the tanker, with a test on each; the shared cause is named in this ticket.

### Result

Measured: same root cause as ticket 01. Every reader of support (`mission_picture.read_mission_picture`, `inspect_built._SUPPORT_TASKS`, the presets injector) keys on the group task `Refueling`; the AI's tanker carried `Tanker`, so the deck's Support line, its map and `inspect_built_mission` all missed it while the `.miz` held the tanker. With the task canonicalised at creation (ticket 01) the readers see it; the fixture's tanker (`Arco`, task `Refueling`) is listed by the deck and the inspection.

## 05 — `build_mission` wipes the briefing pictures

Status: ✅ done

The AI: "`build_mission` overwrites the .miz and wipes briefing pictures → always run `build_mission_briefing` last".
`build_mission_briefing` writes its pictures into the mission folder (`src/mission/l10n/DEFAULT/`, `mapResource`, `pictureFileName*`) and into the built `.miz` (FEAT-MCP-MISSION-BRIEFING), precisely so that a rebuild keeps them.

Measure: `build_mission_briefing`, then `build_mission`, then read the new `.miz` — are the pictures and their `pictureFileNameB/N` entries still there?
If they are gone, find which step of the build drops them (the folder's mission table, or a step that rewrites `mapResource`); if they stay, find what the AI saw instead and say it in the guide.

Done when: a rebuild keeps the briefing pictures, with a test that builds twice; or the measurement shows they were kept and the guide says so.

### Result

Measured, not reproduced. `build_mission_briefing` writes the pictures into the mission folder (`src/mission/l10n/DEFAULT/`, `mapResource`, `pictureFileName*`) **and** into the built `.miz`; the worker's tests check both. On Martinho's run (6.31.4, the worker is unchanged since 6.31.0): briefing, then `build_mission` again, and the final `.miz` holds the three `briefing-*.jpg` and a `mapResource` listing them beside the VEAF keys. The AI of the video (6.31.3, same worker) could have been misled by an unchanged `.miz` modification time, as Martinho's was; its folder is gone.
Fix: none in the build. `inspect_built_mission` now lists the pictures and whether the archive holds each (ticket 14), so the AI can check instead of guessing.

## 06 — Accents lost in what the AI writes

Status: ✅ done

Measured, 2026-10-22, on Martinho's export and mission folder (6.31.4), and on David's sandbox export (6.31.2): the model writes accented French through `write` and `edit` (README, comments of `waypoints.yaml`) and **unaccented** French inside the JavaScript it passes to `execute` — `set_briefing` (`colonne blindee`, `noeud logistique`, `Detruire`), `build_mission_briefing`, `create_combat_zone` (`friendly_name`, `briefing` in `mission.yaml`). Its own reasoning, drafted a step earlier, had the accents.
The tools are not the cause: `set_briefing` called by hand with `é`, `œ`, `É` stores them intact in `src/mission/mission`, and no code on the path normalises to ASCII.
The one place the guide asks for ASCII is the mission's *name* (`VEAF_<Map>_<Title>`, title without accents); the model probably carried it over to all its text.

Fix, in the two places that can act:

- The guide and the objective prompt (FR, EN): what a player or a mission maker reads — briefing, objectives, zone titles, threats, notes — is written in its language **with its accents**, also inside a tool call; only identifiers (mission name, zone and group names, callsigns) stay ASCII.
- A warning, never a refusal: `set_briefing`, `build_mission_briefing` and `create_combat_zone` say so when a French text of some length carries no accented letter while it uses common French words that take one.

Done when: the guide and the prompt say it, the warning is tested both ways (an unaccented French text warns; an accented one, an English one and a short one do not), and the warning names the text and the fix.

### Result

Fix: `veaf_mission_mcp/accents.py` (`missing_accents_warning`) judges a text of some length with no accented letter that uses two different French words that take one (a list of unambiguous unaccented spellings, no word that is also English); `set_briefing`, `build_mission_briefing`, `create_combat_zone` and `add_combat_operation` return the warning, never refuse. The guide and the objective prompt (FR, EN) say what a player reads keeps its accents, also inside a tool call. Tests: the helper both ways, and each action.

## 07 — Waypoint numbers in the briefing do not match the route

Status: ✅ done

Measured on Martinho's folder: `waypoints.yaml` declares INGRESS, IP, **BULLSEYE**, NOEUD, COLONNE, EGRESS, OVDA — the AI added BULLSEYE third after seeing the build inject its own at 20 000 ft. The briefing's text (`Detruire le noeud (W3)`, `la colonne (W4)`, `Rentrer a Ovda (W6)`) and the F10 labels (`W3 NOEUD`, `W4 COLONNE`) were written before, for a route of six points; the route has seven, and the deck's flight-plan page numbers NOEUD 4, COLONNE 5, OVDA 7.
The prompt asks for a render check ("each waypoint number matches the route") that a machine without PowerPoint cannot do, and nothing in `build_mission_briefing` compares them.

Fix:

- The guide says to declare BULLSEYE **last** (the build already appends its own at the end when none is declared), so it does not shift the numbers; and the prompt says to name a waypoint rather than number it, or to number after the route is final.
- `build_mission_briefing` compares every `W<n>` (and `WP<n>`) of the words it receives with the route of the built mission and warns on a number past the route's end or on a number whose name the same sentence contradicts.

Done when: a test builds a deck with a text citing a waypoint that does not exist, and the warning names it; a route-consistent text gives none.

### Result

Fix: the prompt and the guide say to declare the BULLSEYE last and to cite a waypoint by its name; `mission_briefing_worker._waypoint_warnings` compares every `W<n>` of the words with the route of the built mission (past its end, or contradicted by the point the same line names) and returns warnings. Tests: `TestWaypointNumbers` on the fixture's route POTI, KHOBI, BULLSEYE.

## 08 — A PDF of the briefing, from the executable

Status: ✅ done

The objective prompt offers "PPTX + PDF" but `build_mission_briefing` writes the PPTX only. Without PowerPoint, two runs improvised: David's demo video wrote `tools/render-briefing.ps1`, an HTML render printed by Edge ("wrapping may differ by a line"); Martinho's run installed LibreOffice by `winget` (fifteen minutes with no output, then an MSI that failed with 1603 for lack of elevation, half installed). A mission maker who has neither Office nor Edge is left with no PDF.

Fix: `build_mission_briefing` writes `docs/briefing.pdf` itself, with `fpdf2` (pure Python, embedded in the executable) and a bundled font with the accents — drawn from the same `Page`/`Block` lists and the same map images as the deck, so the two carry the same words, page for page. It is the deck's content with its own layout, not a pixel copy of the PPTX; the prompt says so. The action's result reports the PDF and its page count.

Done when: a mission's briefing gives a PDF with the deck's page count; its text, read back, equals the deck's text page by page, accents included; the font file ships with the executable (`veaf-build` data); the prompt no longer sends the AI to install software or to write a converter.

### Result

Fix: `mission_briefing/briefing_pdf.py` draws the deck's pages (the same `Page`/`Block` lists and maps, in the same order) with `fpdf2` and DejaVu Sans 2.37 (regular and bold, with the licence, bundled in `veaf_libs/data/fonts/` and in the executable's data). The result carries `pdf` and `pdf_pages`. The font was taken from github.com/dejavu-fonts/dejavu-fonts (release 2.37) with David's agreement; it covers every character the briefing uses (œ, «», —, ≈, →). Tests: the PDF's text, read back with `pypdf`, holds every word of the deck, accents included; the bundled font; a map page; a long page running on.
Known difference: layout and page breaks are the PDF's own, so `pdf_pages` can exceed the deck's page count.

## 09 — `read_mission_file` takes `path`

Status: ✅ done

Martinho's session: `read_mission_file` called with `path` failed with `missing required parameter(s) file; unknown parameter(s) path`, one turn lost; every other file action of the AI's tools reads a `path`-like word. The tool's own `edit`/`read` tools of the assistant use `path` too, so a model reaches for it first.

Fix: `read_mission_file` accepts `path` as an alias of `file` (and says in its schema that `file` is the name). Both given and different is refused naming both.

Done when: a test reads a file by `file`, by `path`, and refuses two different ones.

### Result

Fix: `ActionCatalog` reads `path` as `file` for an action that publishes `file` and no `path` (both given and different: refused). Tests in `test_catalog.py`.

## 10 — `add_group` and the coalition `neutral`

Status: ✅ done

Martinho's session: `add_group` for the village's houses with the coalition `neutral` answered `KeyError: "Unknown coalition: 'neutral'"` — no list of the valid ones, a raw exception name. The AI put the houses on red.

Measure first: which of `add_group`'s coalitions the mission table can hold (DCS has `neutrals` as a coalition for countries, statics included); if a neutral static is faithful to what the Mission Editor writes, accept it; otherwise refuse with the valid values.

Done when: a test either places a neutral static or gets a refusal that names `blue` and `red`; the result of the measurement is written here.

### Result

Measured: a DCS mission table holds `coalition.neutrals` (Martinho's `src/mission/mission` has it), so a neutral static is faithful. `add_group` read `neutral` literally. Fix: `neutral` is read as `neutrals`, and an unknown coalition names what the mission holds. Tests in `test_group_insertion.py`.

## 11 — `validate_mission` and dynamic slots

Status: ✅ done

Martinho's session: `validate_mission` warned "`waypoints.yaml` est configuré mais la mission n'a aucun groupe d'aéronefs où injecter des waypoints" on a mission whose dynamic-slot template did receive the route (`routes_on_player_groups: 1` in the build report, the route read back from the `.miz`). The warning is wrong for a mission of dynamic slots only, and the AI reported it.

Fix: the check counts the dynamic-slot templates of the mission (the groups the waypoints injector gives a route to) as aircraft groups to inject into.

Done when: a test with a dynamic-slot template and no flight gives no such warning; one with neither still does.

### Result

Fix: `_check_presets_waypoints` skips the "no aircraft" warning when the mission offers dynamic slots, as the presets check beside it already did. The test fails without the fix (checked) and the case with no aircraft at all still warns.

## 12 — The clear-ground message says what the catalogue covers

Status: ✅ done

The sessions' warning, "no clear-ground catalogue covers this place on <theatre>", was read by the AI, and relayed to the user, as "GermanyCW has no terrain-object catalogue" (David's sandbox, Caucasus too). Measured in the repository: both catalogues ship since 6.26.0 — GermanyCW covers 25 trigger zones of the Open Training (Baumholder, Wahner Heide, Borkenberge, Brocken, the three convoy motorways…), the Caucasus covers 21 airfields. A place anywhere else is covered by neither; only a survey flown in DCS can change that.

Fix: the warning names what the theatre's catalogue does cover (its airfields and zones, or "none" for a theatre without one) and gives the sweep command ready to run for the place (`veaf-tools dcs clear-ground-sweep <theatre> --around X,Y`), in the language of the mission. The limitation stays recorded (`kind: tool`) because widening the catalogue is a survey, see FEAT-CLEAR-GROUND-COVERAGE.

Done when: the warning of `add_group`, `create_combat_zone` and `add_farp` carries the coverage and the command, with a test on a covered theatre and on one with no catalogue.

### Result

Measured: the GermanyCW catalogue holds 25 zone layers, the Caucasus one 21 airfield layers, 6 km round each (`known-limitations` entry `clear-ground-covers-what-was-swept`); a local sweep wins over the shipped one (`catalogue_for_theatre`). The warning already carried the `clear-ground-sweep … --around X,Y` command; it did not say what the catalogue covers.
Fix: `coverage_summary` names the number and the first places of the theatre's catalogue ("the GermanyCW catalogue holds 25 surveyed place(s) only (Baumholder_Easy, …)") or says the theatre has none; used by the placement of `add_group` and `create_combat_zone`, and by `add_farp`. The limitation entry says so.

## 13 — `create_combat_zone` takes statics and vehicles together

Status: ✅ done

Martinho's session: `create_combat_zone` accepts one `category` per call, so the zone was made with its vehicles and its thirteen statics were added one `add_group … for_combat_zone` call each. David's sandbox run reports the same: a `groups[].units[]` list that fails as a whole after the call.

Fix: the `groups` of `create_combat_zone` each carry their own `category` (vehicle, static, infantry…); the default stays the call's. A group that cannot be built (a static with `count > 1`) is named in the refusal **before** anything is written.

Done when: one call makes a zone with vehicles and statics, with a test; a refused group leaves the mission untouched.

### Result

Fix: a group's own `category` overrides the call's in `create_combat_zone`; a group `insert_group_into_content` refuses is named ("group 'CZ-Depot-bunker': a static is one object…") and, since the mission is saved last, nothing is written. Tests: a zone of vehicles and statics in one call; a refused group leaves `src/mission/mission` and `mission.yaml` byte for byte as they were.

## 14 — `inspect_built_mission` shows the date and the briefing pictures

Status: ✅ done

Martinho's session: the AI could not confirm the mission's **date** from `inspect_built_mission` (time only) and opened the `.miz` with a shell to see whether the briefing pictures were in (`l10n/DEFAULT/*.jpg`, `mapResource`) — against the guide's "never read a mission through a shell".

Fix: `inspect_built_mission` reports the date with the time, and the briefing pictures (the `mapResource` keys and whether each file is in the archive and listed for the players' side).

Done when: a test builds a mission with a briefing and finds the date and the pictures in the inspection; one without pictures says none.

### Result

Fix: `inspect_built_mission` puts the date before the time on each weather line (`main: 2015-10-13 06:15, …`) and gains `briefing_pictures`: each resource, its file, whether the archive holds it, and the sides it is listed for (`absent` without any). Test: before and after `build_mission_briefing`.
