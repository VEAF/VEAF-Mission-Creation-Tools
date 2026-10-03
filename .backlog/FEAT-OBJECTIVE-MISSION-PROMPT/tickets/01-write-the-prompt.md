# 01 — write the prompt (FR + EN) and point to it from the mission-maker doc

Status: ✅ done

Files: `.prompts/new-objective-mission.fr.md`, `.prompts/new-objective-mission.en.md`,
`doc/mission-maker/AI_ASSISTANT_INSTALL.md` / `.en.md`, `CHANGELOG.md`.

## Done when

- Two phases with a strict line between them: numbered scenario sheets (one screen each, distances
  measured, flight time computed against the session length), questions answered, a pre-briefing in
  the conversation on request, **no write action** before an explicit approval of an identified
  scenario.
- The VEAF briefing template described page by page from *Deep Strike Palmyra* (cover, general
  situation, ATO, tactical situation + one zoom per objective, mission flow, flight plan, frequency
  plan, target coordinates).
- Build rules reusing what the Open Training prompt learnt where it applies (nothing from memory,
  carriers of the generated class, airfield channels from DCS, map generated from the mission's data,
  pictures on the blue and neutral lists only, opaque F10 labels), and the objective-mission specifics:
  one group per ATO flight, no dynamic slots, objectives as combat zones active at start,
  `chained_zones` for phases, route ↔ threat distances measured, a single weather.
- The briefing file generated from the **built** mission (coordinates, frequencies, flight plan,
  callsigns read back), not from the scenario.
- Gaps found while writing it: no action gives the ground elevation (stated in the prompt as a
  "Feedback for VMCT" item, lot FEAT-TERRAIN-ELEVATION); no end-of-mission message and no map object as
  an objective (closed by tickets 02-05, which the prompt then uses: objectives grouped in an operation
  active at start, `scenery_targets` found with `offer_scenery_lookup`).
