# FEAT-MCP-PROMPTS — the MCP server publishes prompts a pilot fills in

Status: 🔄 in progress

Asked by David on 2026-11-27, from the local-model test session. Measured the same day with a trial server (`MCPServer` of `mcp` 2.x, `@prompt`) in Cherry Studio 2.2.3: the server's prompts appear in Cherry; choosing one opens a dialog "Renseigner les arguments du prompt" (each argument's name and description); the text the server returns is inserted into the input box, which the user rereads and sends. The model receives that text.

Goal: a friend who is not a developer starts "New mission" by filling a few fields instead of pasting a block of text.

## Scope

- `veaf_mission_mcp/prompts.py`: four prompts, registered on the server with `@mcp.prompt` (SDK `mcp` 2.3.0, already the one the tools use; no SDK change).
  - `nouvelle_mission`: name, map, date, local time, weather, scenario, mission folder.
  - `ajouter_qra`: mission folder, base, zone centre `x`/`y`, radius, aircraft, delay, side.
  - `ajouter_zone_de_combat`: mission folder, name, `x`/`y`, radius, content, side.
  - `ajouter_jtac`: mission folder, `x`/`y`, laser code, frequency, modulation.
- Typed arguments (`float`, `int`, `str`) with French descriptions, the pilot's language. The prompt text is French too, taken from the blocks of the "Marteau du Golan" tutorial that worked on the local model: DCS `x`/`y` already converted, "validate and build once, at the end", explicit mission path.
- The QRA delay keeps its exact meaning: seconds from the **first intrusion**, not from the mission start.
- Coherent with both profiles and with `describe_authoring_guide`: a prompt cites only actions of the catalogue, and only ones the guide's recipe or its `more` section already names. A test checks both.
- No MCP resources in this lot.

## Out of scope

- English text of the prompts: the arguments and the pilot reading them are French; the model answers in the user's language. Add `lang` only if a non-French user asks.
- Prompts for a persistent campaign or an Open Training (their long prompts stay behind `describe_mission_prompt`).

## Definition of done

Tests through the SDK client (`prompts/list`, `prompts/get`: defaults, missing required argument, bad type, special characters); docs `doc/developer/mission-editing-mcp` and `doc/mission-maker/AI_ASSISTANT_INSTALL`, FR and EN; `CHANGELOG.md`; quality gate; `pr-code-review`.

## Tickets

1. [Prompt texts and registration](tickets/01-prompts-module.md)
2. [Tests through the SDK client](tickets/02-tests.md)
3. [Documentation](tickets/03-docs.md)
