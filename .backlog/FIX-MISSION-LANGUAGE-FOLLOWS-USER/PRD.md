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

## Tickets

- [01 — The English prompts build an English mission](tickets/01-english-prompts.md)
