# FEAT-OBJECTIVE-BRIEFING-QUALITY — an objective mission's briefing a squadron can brief from

Status: ✅ done · archived 2026-11-24

David's review of the briefing `build_mission_briefing` wrote for "Marteau du Golan" (Syria, VMCT 6.33.0, flown 2026-10-29), six points.
Measured on that mission's `docs/briefing.pptx`: the ATO ran over six slides listing the 61 aircraft types each of the two bases offers in dynamic slots; the overview was 715 × 628 px beside a legend taking half the slide; the targets page was a list of names and DMS; the kneeboard flight cards were mostly the radio presets the build had already put in the cockpits.

| # | David's point | Ticket |
|---|---|---|
| 1 | With dynamic slots the ATO lists every type a base offers: say "dynamic slot", the base and the flights' callsigns | 01 |
| 2 | The overview is unreadable: framed on the useful area, free orientation with a north arrow, a much higher resolution, a compact legend | 02 |
| 3 | A locator inset on each objective zoom; target sheets rather than a bare list | 03 |
| 4 | A "strategic situation" page, and prose accepted in the existing headings | 04 |
| 5 | The flight plan step by step, as the DCS kneeboard does, and a "deployment and coordination" page | 05 |
| 6 | No radio plan on the kneeboard flight cards: the presets are already in the cockpits | 06 |

Decided with the brief (2026-10-28): every existing parameter keeps its meaning; every new text is optional and its page is left out when it is empty; fonts Google Slides knows (Calibri); the PDF follows the deck; the action's documentation and the objective prompts follow in the same lot; a test for each point.

One branch, one PR.

## Tickets, in full

## 01 — ATO: dynamic slots say so, with the flights' callsigns

Status: ✅ done

The ATO of a dynamic-slot base listed every type the base offers (61 on Ramat David, six slides for two bases). A new optional `flights` parameter names the package's flights (callsign, base, aircraft, count, task); a base offering dynamic slots shows one line, "dynamic slot", then those flights with their pilot boxes. Without `flights` the base's line and one row of pilot boxes, never the types.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`PackageFlight` and the `flights` parameter; `_ato_page` lists them under their base (`Ninja — 2 × F-16C — SEAD (slot dyn)`, pilot boxes as many as `count`), those of no base offering slots under "any base" with a warning. `mission_reader.slot_flights` and `SlotFlight` are gone. Measured on Marteau du Golan: the ATO is one slide, it was six. Tests: `TestDynamicSlotAto`, `test_the_flights_on_dynamic_slots_reach_the_ato`.

## 02 — A readable overview

Status: ✅ done

The overview is framed on the route, the departures, the objectives and the threats' positions (not the full detection circles, nor the tankers' tracks), turned when that holds the frame tighter (north arrow drawn), rendered at about twice the resolution with every symbol scaled, and its legend drawn into the map as a compact symbol key: the slide gives the map its whole width.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`MapCanvas(width=…, rotation=…)`: a framed canvas, symbols and fonts scaled by `k`, turned after the symbols are drawn (`turn`), labels set level afterwards, `north_arrow`, `free_corner`; `best_rotation` keeps north up unless a turn gains 15 %. Callers giving no width keep the north-up 1400 px map. The overview is framed on route, departures, objectives, threats where they stand, carriers and bullseye; 2000 px at 2:1 on the slide's whole width, its key drawn inside. Measured on Marteau du Golan: 3738 × 1869 px, turned, the key top left. Tests: `TestTheReadableOverview`, `TestTheRotation`.

## 03 — Locator inset on the zooms, target sheets

Status: ✅ done

Each objective zoom carries a small inset of the overview with the zoom's place marked. The target coordinates become sheets, several per slide: name, what it is (unit type and count), coordinates in DMS and degrees-decimal-minutes, elevation, and a thumbnail cut from the zoom.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`Inset` on every zoom (deck and kneeboard), the zoom's place circled on the overview. `briefing_cards.py`: `Card`, `CardSection`, six to a slide in the deck and the PDF; a target's card carries its units' types (`Target.kind`), DMS and DDM, elevation, a thumbnail of its zoom. Tests: `test_briefing_cards.py`, `TestTheInset`, `TestTheSheets`.

## 04 — Strategic situation page, prose accepted

Status: ✅ done

A new optional `strategic_situation` text makes its own page after the cover. A text passed as one string is split on blank lines into paragraphs, in every heading; `mission_bullets` passed as a string is prose, without the dashes.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`strategic_situation` page after the cover; `_lines` splits one string on blank lines; `mission_prose` drops the dashes. Tests: `TestProse`, `test_a_text_given_as_one_string_is_split_into_paragraphs_and_a_mission_string_is_prose`.

## 05 — Step-by-step flight plan, deployment page

Status: ✅ done

The flight plan becomes step sheets, one per waypoint: its number and name, coordinates, altitude, heading and distance from the previous point, highest ground on the leg, and what is done there (new optional `waypoint_notes`, by waypoint name), with a thumbnail of the overview. A new optional `deployment` text makes a "deployment and coordination" page.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`route_steps` shared by the kneeboard flight card and the step sheets; one card per waypoint with the leg from the previous point, DMS, DDM, altitude, the `waypoint_notes` text (a name the route lacks is warned) and a thumbnail of the overview. `deployment` page after the flow. Tests: `TestTheSheets`, `test_the_deployment_and_the_waypoint_notes_reach_the_deck`.

## 06 — Kneeboard flight cards without the radio plan

Status: ✅ done

The flight card pages keep the points, headings, distances and highest ground, and drop the radio blocks: the presets are already in the cockpits.

Done when: the behaviour is covered by a test, and the action's documentation says it.

### Result

`flight_card_blocks` takes no radio plan any more. Test: `test_the_flight_card_gives_heading_and_distance_and_no_radio_plan`.
