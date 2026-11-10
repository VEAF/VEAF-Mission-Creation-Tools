# 01 — Kneeboard only, and free text sheets

Status: ✅ done

## Done when

- `build_mission_briefing` (worker and MCP action) takes an option that writes **only** the kneeboard: no `briefing.pptx`, no `briefing.pdf`, no DCS briefing picture added or replaced; the mission's existing briefing pictures are untouched (test on a built `.miz` holding pictures of its own).
- The briefing content takes a list of sheets — a title and paragraphs — laid out with the existing `text_pages`, first in the kneeboard, in the order given (test).
- Without the option and without sheets, the output is byte-for-byte what it was (existing tests unchanged).
- A mission with no flight plan and no code word gets no flight card and no code-word page (test, if not already covered).
- The MCP action's catalogue entry documents both (CLAUDE.md, MCP action catalogue lockstep).
