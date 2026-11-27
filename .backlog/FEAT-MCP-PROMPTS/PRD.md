# FEAT-MCP-PROMPTS — the MCP server publishes one prompt per kind of mission

Status: 🔄 in progress

Asked by David on 2026-11-27, from the local-model test session. Measured the same day with a trial server (`MCPServer` of `mcp` 2.x, `@prompt`) in Cherry Studio 2.2.3: the server's prompts appear in Cherry; choosing one opens a dialog "Renseigner les arguments du prompt" (each argument's name and description); the text the server returns is inserted into the input box, which the user rereads and sends. The model receives that text.

Goal: a friend who is not a developer starts a mission by filling a few fields instead of pasting a block of text.

**Reframed the same day** (David, through the control session): one prompt per **kind of mission**, not per component (QRA, combat zone, JTAC). The first draft, four component prompts, was dropped; the registration skeleton and the test harness stayed.

## Phase 1 — coded

`veaf_mission_mcp/prompts.py`, registered in `server.py` with `mcp.prompt` (SDK `mcp` 2.3.0, the one the tools use; no SDK change):

| Prompt | Sends the model to | Required | Optional |
|---|---|---|---|
| `mission_one_shot` | `describe_mission_prompt` kind `objective` | `carte` | `appareils`, `duree` (2 h), `genre`, `opposition`, `langue` (fr), `dossier` |
| `open_training` | kind `open-training` | `carte` | `epoque` (moderne), `gabarit` (standard), `langue`, `dossier` |
| `campagne_persistante` | kind `persistent-campaign` | `carte`, `nom` | `epoque` (moderne), `camp` (bleu), `fichier`, `langue`, `dossier` |

A prompt **does not copy** the mission prompt. It returns a short message: the answers already given, `lang`, the folder, and the order to read the guide, load the prompt of its kind with `describe_mission_prompt` and follow it from its first section. The guide and the mission prompts stay the single source.

### Which answers become arguments, and which stay with the mission prompt

The rule: an answer becomes an argument when it is **closed** (a name, a value from a short list) and **asked first** by the mission prompt. It stays with the prompt when it needs a discussion, a table validated, a measure, or depends on another answer.

Become arguments (the prompt's start questions, §1 of each):
- `carte` — question 1 of the three prompts; closed.
- `appareils`, `duree`, `genre`, `opposition` (objective, questions 2 to 5) — free text but short; each says "blank: the model asks / proposes", so a pilot who fills nothing loses nothing. `duree` defaults to 2 h, the prompt's own recommendation.
- `epoque` (open training Q2, campaign Q1) — closed list; default modern.
- `gabarit` (open training Q3) — closed list; default `standard`, the prompt's recommendation.
- `camp`, `nom`, `fichier` (campaign Q2) — closed; `fichier` stays optional because the prompt proposes one.
- `langue` and `dossier` — not a numbered question but every prompt starts with them (the guide: `lang`; "empty folder, otherwise ask"). `langue` is checked against `fr`/`en`; a blank folder makes the model ask, nothing is invented.

Stay with the mission prompt, and why:
- **Date, time, weather** — none of the three asks the user for them. The objective prompt proposes them inside the scenario; the Open Training derives the date from the era; a persistent campaign fixes **none** (the server's MizEdit sets them at each load). An invite argument would contradict the prompt or the campaign rule.
- **Scenario, objectives, threat** (objective) — discussed over several turns; the user may ask for other scenarios; nothing is written until one is approved.
- **Slot mode** (objective Q2) — depends on the aircraft answer and sizes the threat; asked after it.
- **An existing mission to take inspiration from** (Open Training Q4) — needs the user to point at a mission and the prompt to read it (§3).
- **Escorts** (Open Training Q5) — depend on where the tankers' orbits fall, decided later.
- **The front, the zones, factories and depots, long-range SAMs, the enemy AI** (campaign Q3 to Q6) — the zone map is a table the user validates before anything is written; the rest follows from it. The enemy AI keeps the shipped values unless asked.

## Phase 2 — not coded

Prompts to edit an existing mission, one per kind of change. Only the list is prepared: [PHASE-2-EDIT-PROMPTS.md](PHASE-2-EDIT-PROMPTS.md), families the action catalogue allows, with their typical arguments and the actions they call. David decides which to build.

## Out of scope

- A "map mapping" prompt (preparing a new DCS map for VEAF): data maintenance, not a prompt.
- English text of the prompts: the argument descriptions and the message are French, what a French-speaking pilot reads; the model answers in the user's language and loads the mission prompt in `lang`.
- MCP resources.

## Definition of done

Tests through the SDK client (`prompts/list`, `prompts/get`: defaults, missing required argument, language refused, blank fields, special characters, each cited action in the catalogue and in the guide, compact profile); docs `doc/developer/mission-editing-mcp` and `doc/mission-maker/AI_ASSISTANT_INSTALL`, FR and EN; `CHANGELOG.md`; quality gate; `pr-code-review`.

## Tickets

1. [Prompts module and registration](tickets/01-prompts-module.md)
2. [Tests through the SDK client](tickets/02-tests.md)
3. [Documentation](tickets/03-docs.md)
4. [Phase 2 list](tickets/04-phase-2-list.md)
