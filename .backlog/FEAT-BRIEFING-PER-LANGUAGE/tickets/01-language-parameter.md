# 01 — A `language` parameter, writing only the archives of that language

Status: ⬜ ready

`build_mission_briefing` gains an optional `language` (`fr`, `en`), defaulting to the mission's (`mission.language` of `mission.yaml`, as today).

- **Texts:** the deck, the PDF, the maps' labels and the kneeboard pages are written in that language (`with language(...)` takes it instead of `_mission_language`).
- **Archives:** pictures and kneeboard pages go only into the archives of that language, read from each archive's `l10n/DEFAULT/veaf-config.lua` (`veaf.config.language = "en"`, written by the profile; no such line = the mission's language). An archive of another language is left as it is, pictures and pages included: the stale-page cleanup must not remove the other language's pages.
- **Folder:** a call in the mission's language writes the folder as today (`l10n/DEFAULT/`, `KNEEBOARD/IMAGES/`, `docs/briefing.pptx`, `docs/briefing.pdf`, `docs/maps/`), so a rebuild carries them.
  A call in another language does not touch `src/mission/` (the next build would carry its pages into every archive) and writes its deck, PDF and maps beside the others with the language before the extension: `docs/briefing.en.pptx`, `docs/briefing.en.pdf`, `docs/maps/*.en.jpg`.
- **Report:** `archives` lists only the archives written; a call that matches no archive warns ("no built mission in English: is the EN profile built?").

The order a bilingual mission follows is then: build, then one call in the mission's language, then one call per other language, each after every build.

Tests: two calls on a folder holding a French and an English variant → each archive carries its own language's pages (read back from the JPEG members or the deck's text), the folder's pages are the mission's language, the second call removes no page of the first; a call in a language no archive has warns and writes nothing into an archive.

Done when: the tests pass, the action's schema and description say it, the catalogue page (`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`, `#mission-briefing`) and the objective prompt say how to brief a bilingual mission, and the demo mission's batch (VEAF/VEAF-Demo-Mission-v6, `tools/batches/11-briefing.json`) runs as it is.
