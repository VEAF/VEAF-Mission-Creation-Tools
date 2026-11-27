# FIX-MISSION-LANGUAGE-FOLLOWS-USER — an English-speaking user gets an English mission

Status: ✅ done · archived 2026-11-24

Origin: David's test on 6.31.2, 2026-10-22 — OpenCode with DeepSeek v4.1 Flash (free), spoken to in English ("create a DCS mission").
The AI answered in English, and wrote `mission.language: fr`, a French briefing deck, French maps and a French `README.md`.

## Cause

The English mission prompts said so, and the AI followed them to the letter:

| Prompt | What it said |
|---|---|
| `new-objective-mission.en.md` | "Answer in English, concisely, but write the mission and its briefing in French — the VEAF servers' language — unless told otherwise." |
| `new-objective-mission.en.md` | "The briefing is written in French, like the mission", and the template's French headings and "Armement libre" |
| `new-objective-mission.en.md` | "`mission.language: fr` and a French briefing" |
| `new-open-training-mission.en.md` | "`mission.language: fr` and briefing in French", and the README "in French" |

The tools themselves were right: `build_mission_briefing` and the build follow `mission.language`.
The AI did announce "Mission and briefing will be written in French … unless you'd rather have English", in the middle of its scenario sheet, where it was easy to miss.

## Decision (David, 2026-10-22)

The mission takes the language the user speaks — `mission.language`, the briefing, its maps, the README — unless they ask for another.
The English prompts say English; the French prompts already said French; the authoring guide says the rule once, since it is what picks the prompt's language.

## Also in this lot

The same test showed the AI telling the user GermanyCW had no parking places for dynamic slots, misled by the id of a known limitation (ticket 02).
David then captured the parking of the five maps he owns that had none, so they ship in the same release (ticket 03).
Before the release, David asked for the open Dependabot alerts (ticket 04) and the two findings the security-audits quality pass still held open (tickets 05 and 06) in the same PR.

## Tickets

- [01 — The English prompts build an English mission](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)
- [02 — The parking limitation says what it concerns](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)
- [03 — Five more maps ship their parking](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)
- [04 — Pillow 13 and certifi 2026.10.19](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)
- [05 — "0 aircraft" also stops the combat missions' auto scale (issue #1151)](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)
- [06 — The campaign state write is checked (issue #1146)](FIX-MISSION-LANGUAGE-FOLLOWS-USER.md)

## Tickets, in full

## 01 — The English prompts build an English mission

Status: ✅ done

`new-objective-mission.en.md` and `new-open-training-mission.en.md`: `mission.language: en`, an English briefing and README, the template's English headings and "Free loadout"; `authoring-guide.md`: the mission takes the user's language unless they ask for another.

Done when: `test_an_english_prompt_builds_an_english_mission` fails on the old prompts and passes on the new ones (both measured).

## 02 — The parking limitation says what it concerns

Status: ✅ done

Same test, 2026-10-22: offering the maps, the AI wrote of GermanyCW "pas de places de parking pour les slots dynamiques".
Wrong: DCS places dynamic-slot players itself, with no capture; the parking capture only serves the ramp and runway starts of the flights the tools place (`add_air_group`, a QRA on the ground).
The AI had only the short listing of `describe_known_limitations`, which gives each entry's id, and the id read `no-parking-data-outside-three-theatres` — wrong besides, six theatres ship a capture.

The entry is now `ai-ground-start-needs-a-parking-capture`, its title says dynamic slots are not concerned, and its symptom records the old id.

Done when: `test_the_parking_limitation_says_dynamic_slots_are_not_concerned` fails on the old entry and passes on the new one (both measured).

## 03 — Five more maps ship their parking

Status: ✅ done

Asked by David after ticket 02, 2026-10-22: the maps he owns with no parking capture got one, for 6.31.3.

One blank mission per map (`scaffold_mission` minimal, `dcs_bridge` enabled, built), loaded in DCS by David one after the other; `veaf-tools capture-map --parking` run against each through `dcs-serve`; the dumps slimmed by `veaf-build update-dcs-data --parking`.

| Map | Airfields with stands | Stands |
|---|---|---|
| Afghanistan | 26 of 29 | 1 435 |
| GermanyCW | 227 | 7 035 |
| MarianaIslands | 8 | 282 |
| MarianaIslandsWWII | 11 | 534 |
| TheChannel | 12 | 616 |

Measured after the slimming: `add_air_group` with `start: parking-cold` places a flight on a stand on each of the five (Ramstein, Manston, Bagram, Andersen AFB, Agana).
Iraq, Kola and Nevada remain without a capture: nobody who captures owns them.

Done when: `test_parking_captures_2026_10_22.py` holds the counts above, the limitation `ai-ground-start-needs-a-parking-capture` names the three maps left, and the pages that listed the parking maps (`PIPELINE_REFERENCE`, `concepts/dynamic-slots`, both languages) are up to date.

## 04 — Pillow 13 and certifi 2026.10.19

Status: ✅ done

Asked by David before the 6.31.3 release, 2026-10-22: the open Dependabot alerts, in this PR.

- Pillow 12.3.0 → 13.0.0 (`pyproject.toml` `>=13.0,<14`): 14 alerts, one critical (heap overflow in `ImagingJpegDecode`), nine high. Dependabot's own PR #1164 is superseded by this one.
- certifi 2026.4.22 → 2026.10.19: one critical alert, emSign root CAs whose intermediate keys were compromised; no Dependabot PR existed. The tools use it for every download (self-update, terrain data, map tiles).

`poetry.lock` changes those two packages only (measured: the only `version` lines in its diff).

Done when: the full Python suite and the CI pass on the new versions, and the Dependabot alerts close.

## 05 — "0 aircraft" also stops the combat missions' auto scale (issue #1151)

Status: ✅ done

Found by the security-audits quality pass of 2026-10-19 (`opposition-zero-avion-combat-missions-non-coupees`).
"0 aircraft" fixed from the Opposition menu (or `_opposition 0`) announced "no enemy fighters (fixed)" and silenced the QRAs, but a combat mission started through "Auto scale (opposition level)" still took off at its smallest scale: `scaleForOppositionLevel` cannot tell a 0 fixed by hand from a 0 counted.

`ActivateMissionAtOppositionLevel` now checks `veafOpposition.isNoAircraft()` first: it starts nothing and tells whoever asked (`combatmission.no_aircraft`).
A 0 counted from the players keeps its smallest scale, and a scale chosen by hand always starts.
`veafQraManager` page, both languages: the zero-aircraft paragraph says so.

Done when: `test_no_aircraft_fixed_activates_nothing_and_says_so` fails on the old code and passes on the new (both measured).

## 06 — The campaign state write is checked (issue #1146)

Status: ✅ done

Found by the security-audits quality pass (`campagne-ecriture-etat-non-verifiee`).
`veafCampaign.writeState()` ignored what `file:write` and `file:close` answered; writes are buffered, so a full disk shows up at `close`.
A truncated temporary was then moved over the previous, valid state.

`writeTo` now checks both and fails without touching the previous file.
The remove-then-rename stays: with the temporary now known complete, a rename that fails after the remove leaves that temporary, which `campaign apply` already reads when the file is missing.

The test fake now follows the Lua 5.1 contract (`write` returns the file, `close` returns `true`, both `nil` and a message on failure).

Done when: `test_a_failed_write_keeps_the_previous_state` and `test_a_failed_close_keeps_the_previous_state` fail on the old code and pass on the new (both measured).
