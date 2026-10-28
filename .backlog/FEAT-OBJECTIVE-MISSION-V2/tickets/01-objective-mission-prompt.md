# 01 — The objective-mission prompt learns what Marteau du Golan did by hand

Status: ✅ done

The scenario and build parts of `describe_mission_prompt` (objective): (A1) the briefing's prose in a file, validated before the layout; (A2) a scripted event is told as intelligence expects it, never as certain; (A3) uncertainties and Mission Maker instructions out of the pilots' briefing; (A4) a Mission Maker sheet (F10 commands with their exact path, what to do by turnout); (A5) ways out from the scenario on: an AI CAP on demand, secondary objectives and SAMs outside the operation, an operation that ends with few pilots; (A6) code words and who talks to whom; (A7) every zoom re-read for units in buildings when the theatre has no clear-ground catalogue.

Done when: covered by a test, and the documentation says it.

## Result

Scenario part: a scripted event told as intelligence, ways out for few pilots (AI CAP, SAMs and secondary objectives outside the operation), code words and who talks to whom, the Mission Maker out of the pilots' briefing, a "with few pilots" line on the scenario sheet; condensed elsewhere to stay under 15 000 characters (fr 14 953, en 14 763). Build part: `docs/briefing-contenu.md` approved before `build_mission_briefing`, `docs/fiche-mission-maker.md`, zoom check for units in buildings, the CAP's `menu_name`, code words and recon photos, the announcement step. Test: `test_the_objective_prompt_carries_what_marteau_du_golan_did_by_hand`.
