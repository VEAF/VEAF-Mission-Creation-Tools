# FEAT-OBJECTIVE-MISSION-V2 — what "Marteau du Golan" did by hand, in the tools

Status: ✅ done · archived 2026-11-24

"Marteau du Golan" (Syria, VMCT 6.33.0, flown 2026-10-29) was designed with the AI and the tools, then finished by hand: the briefing's prose validated before any layout, a separate sheet for the Mission Maker, a combat-area map, kneeboard maps turned attack axis up, recon photos, a poster, a calendar banner and a Discord post.
David found the hand-made briefing far better than the tool's, and asked for what was done by hand to become part of the process (2026-10-28, after FEAT-OBJECTIVE-BRIEFING-QUALITY, #1206).
The prototypes are in `VEAF_Syria_MarteauDuGolan/docs/build/`; their logic is taken over, not their code.

What needs DCS running — taking the recon photos, checking the mission in game — is the other lot, run in parallel (`vmct-recon-ingame`).
This lot fixes the interface it delivers to: a folder of JPEG photos and their JSON sidecars (ticket 04).

| # | What | Ticket |
|---|---|---|
| A | The objective-mission prompt: prose validated first, no scripted event told as certain, Mission Maker matters out of the pilots' briefing and into a sheet of their own, ways out (AI CAP, secondary objectives and SAMs outside the operation, an operation that ends with few pilots), code words and "who talks to whom", every zoom checked for units in buildings | 01 |
| B1 | A second map, "combat area", beside the overview | 02 |
| B2 | Kneeboard: portrait maps turned attack axis up, a coordination page (code words), target pages | 03 |
| B3 | Recon photos per objective, in the deck and the kneeboard | 04 |
| D1 | `create_cap_mission` takes a display name; an empty one falls back to the mission name | 05 |
| D2 | `validate_mission` warns on an unknown key (`friendly_name` in `cap_missions`) | 06 |
| D3 | The authoring guide and the prompt say an operation's zone cannot be deactivated on its own | 07 |
| D4 | Known limitation: an "On Road" route with no path leaves the column still, silently | 08 |
| D5 | `build --profile` writes a `.miz` of its own per profile | 09 |
| D6 | `describe_module CTLD` knows the community modules | 10 |
| D7 | No dynamic-slot templates for a side with no slot base | 11 |
| F | A 16:9 poster, a 5.55:1 calendar banner and a Discord post under 2 000 characters, from the built mission | 12 |

Decided with the brief (2026-10-28): existing parameters keep their meaning; everything new is optional; human texts with their accents; each action's documentation and the `.md` pages concerned follow in the same lot; a test for each point.

One branch, one PR.

## Tickets, in full

## 01 — The objective-mission prompt learns what Marteau du Golan did by hand

Status: ✅ done

The scenario and build parts of `describe_mission_prompt` (objective): (A1) the briefing's prose in a file, validated before the layout; (A2) a scripted event is told as intelligence expects it, never as certain; (A3) uncertainties and Mission Maker instructions out of the pilots' briefing; (A4) a Mission Maker sheet (F10 commands with their exact path, what to do by turnout); (A5) ways out from the scenario on: an AI CAP on demand, secondary objectives and SAMs outside the operation, an operation that ends with few pilots; (A6) code words and who talks to whom; (A7) every zoom re-read for units in buildings when the theatre has no clear-ground catalogue.

Done when: covered by a test, and the documentation says it.

### Result

Scenario part: a scripted event told as intelligence, ways out for few pilots (AI CAP, SAMs and secondary objectives outside the operation), code words and who talks to whom, the Mission Maker out of the pilots' briefing, a "with few pilots" line on the scenario sheet; condensed elsewhere to stay under 15 000 characters (fr 14 953, en 14 763). Build part: `docs/briefing-contenu.md` approved before `build_mission_briefing`, `docs/fiche-mission-maker.md`, zoom check for units in buildings, the CAP's `menu_name`, code words and recon photos, the announcement step. Test: `test_the_objective_prompt_carries_what_marteau_du_golan_did_by_hand`.

## 02 — A combat-area map beside the overview

Status: ✅ done

The overview holds the departures, the tankers and the whole route; the fighting happens in a quarter of it. A second map, framed on the objectives and the threats, follows the overview in the deck, the PDF and the kneeboard.

Done when: covered by a test, and the documentation says it.

### Result

`render_overview_map(combat_area=True)`, `docs/maps/combat-area.png`: page 4 of the deck and PDF, a DCS picture, the kneeboard's second page. Tests: `TestTheCombatArea`, the template's page list.

## 03 — Kneeboard: maps turned attack axis up, coordination, target pages

Status: ✅ done

The kneeboard maps are portrait and turned so that the attack axis — from the players' departure to the objectives — points up, a north arrow saying where north is. A coordination page lists the code words (new optional `code_words` parameter, also a deck page). The targets keep their pages.

Done when: covered by a test, and the documentation says it.

### Result

`attack_axis_rotation`: the true bearing from the departure to the objectives' centre, taken on lat/lon (on the mission grid it was off by the meridian convergence, 6 degrees at Kobuleti, caught by the test); overview, combat area and zooms turned, a north arrow on each. `code_words` make a deck page and a kneeboard page. Tests: `TestTheAttackAxis`, `TestTheCodeWords`.

## 04 — Recon photos per objective

Status: ✅ done

A new optional `recon_folder` parameter: JPEG photos, each with a JSON sidecar (zone, title, heading, pitch, coordinates). One or two per slide after the objective's zoom in the deck and the PDF, and in the kneeboard. The interface is documented; the `vmct-recon-ingame` lot produces the files.

Done when: covered by a test, and the documentation says it.

### Result

`mission_briefing/briefing_recon.py`; `recon_folder` (default `docs/recon/`); two photos per slide and per kneeboard page after the zoom, captioned; strays warned; the result's `recon`. Interface documented in `doc/developer/mission-editing-mcp.md` and sent to the in-game session. Tests: `TestTheReconPhotos`, `test_code_words_and_recon_photos_reach_the_briefing`.

## 05 — create_cap_mission takes a display name

Status: ✅ done

`create_cap_mission` takes `menu_name` and `briefing`; the generator falls back to the group name when `menu_name` is empty: an empty one made a blank F10 entry whose "Infos" failed (Marteau du Golan, 2026-10-28).

Done when: covered by a test, and the documentation says it.

### Result

`menu_name` and `briefing` parameters; the generator falls back to `group_name`; an unread `cap` key is warned. Tests in `test_create_qra_cap.py`, `test_cap_missions_arguments.py`.

## 06 — validate_mission warns on an unknown cap_missions key

Status: ✅ done

`friendly_name` in `cap_missions` was silently ignored. A key the generator does not read is a warning.

Done when: covered by a test, and the documentation says it.

### Result

`CAP_MISSION_KEYS`, `_check_cap_mission_keys`. Tests in `test_mission_validator.py`.

## 07 — An operation's zone has no Deactivate command of its own

Status: ✅ done

Said in the authoring guide and the objective prompt: a zone in an operation's `tasking_orders` can only be deactivated with the whole operation; a zone the Mission Maker may want to switch off stays outside the operation.

Done when: covered by a test, and the documentation says it.

### Result

Authoring guide and both objective prompts. Test: `test_the_guide_says_an_operation_zone_has_no_deactivate_of_its_own`.

## 08 — Known limitation: an On Road route with no path

Status: ✅ done

Measured 2026-10-28 on Syria: a column ordered On Road across the Purple Line at Quneitra stood still 80 s with no message, and left once its first two points were Off Road. Entry in `known-limitations.yaml` (kind dcs), `dcs-runtime-traps.md` regenerated.

Done when: covered by a test, and the documentation says it.

### Result

Entry `on-road-route-with-no-path-stands-still`, page regenerated. Test: `test_a_column_on_road_with_no_path_is_a_known_trap`.

## 09 — build --profile writes its own .miz

Status: ✅ done

`veaf-tools build --profile LOCAL_TEST` wrote the same name as the plain build: one overwrote the other. An explicit profile now suffixes the `.miz` as a build variant does (`<name>_LOCAL_TEST.miz`); `build_mission` says so.

Done when: covered by a test, and the documentation says it.

### Result

`_build_plan` suffixes an explicit profile; `find_built_mission` passes over a profile's archive while the plain one exists. Tests in `test_build_pipeline.py`, `test_campaign_mission_picture.py`.

## 10 — describe_module knows the community modules

Status: ✅ done

`describe_module CTLD` answered unknown: only the VEAF Lua modules were looked up. The community scripts (CTLD, CSAR, AIEN, SKYNET, STTS, TUM, MIST) are known too, with their page.

Done when: covered by a test, and the documentation says it.

### Result

`kind: community` for CTLD, CSAR, AIEN, STTS, TUM, MIST (SKYNET is a VEAF module already). Tests in `test_oracle.py`.

## 11 — No dynamic-slot templates for a side with no slot base

Status: ✅ done

The build injected red's dynamic-slot templates on a mission where red has no base offering slots. The templates of a side whose bases offer none are left out; nothing changes when the source warehouses cannot be read.

Done when: covered by a test, and the documentation says it.

### Result

`dynamic_slot_sides`, `filter_by_sides`, `side_filtered_catalogue`; `pipeline.dynamic_slot_templates.all_sides` keeps them. Tests: `test_dynamic_templates_by_side.py`, and an end-to-end build (`test_a_side_with_no_slot_base_gets_no_dynamic_slot_template`) shown to fail without the wiring.

## 12 — Poster, calendar banner, Discord post

Status: ✅ done

A new action builds, from the built mission and the briefing's maps, a 16:9 poster and a calendar banner at 5.55:1 (the VEAF calendar crops it at the centre), and writes a Discord post under 2 000 characters; the calendar and briefing links and the local time are parameters, never invented.

Done when: covered by a test, and the documentation says it.

### Result

`mission_briefing/mission_promotion.py`, action `build_mission_promotion`: `docs/poster.jpg` 1920 x 1080, `docs/calendar-banner.jpg` 2400 x 432, `docs/discord-post.md` refused over 2 000 characters. Tests: `test_mission_promotion.py`.
