# FIX-MISSION-LANGUAGE-FOLLOWS-USER — an English-speaking user gets an English mission

Status: ✅ done

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

- [01 — The English prompts build an English mission](tickets/01-english-prompts.md)
- [02 — The parking limitation says what it concerns](tickets/02-parking-limitation-id.md)
- [03 — Five more maps ship their parking](tickets/03-five-parking-captures.md)
- [04 — Pillow 13 and certifi 2026.10.19](tickets/04-pillow-certifi.md)
- [05 — "0 aircraft" also stops the combat missions' auto scale (issue #1151)](tickets/05-no-aircraft-auto-scale.md)
- [06 — The campaign state write is checked (issue #1146)](tickets/06-campaign-state-write-checked.md)
