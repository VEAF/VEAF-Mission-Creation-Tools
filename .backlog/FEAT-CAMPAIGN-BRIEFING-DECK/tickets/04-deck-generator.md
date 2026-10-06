# 04 — The deck: `campaign briefing`, and `campaign next`

Status: ⬜ ready

`campaign briefing <folder>` writes `missions/mission-NN/briefing-campagne.pptx` for the coming mission: the pages of the PRD, the generated facts (tickets 01, 02, the objectives, the victory conditions, the annex) around the prose of ticket 03.
`campaign next` produces it too, and the MCP gets a `campaign_briefing` action (catalogue row, lockstep).

- **python-pptx** becomes a dependency: measure what it adds to the frozen executable before taking it.
- VEAF template: 16:9, white, bold title top left, text left-aligned and never justified, Calibri (a font Google Slides knows).
- Military register in everything generated outside the annex (PRD, point 3): "réserves limitées, nos pertes ne seront pas compensées rapidement", not "chaque perte compte pour la mission suivante"; "une unité de la réserve viendra le tenir", not "une garnison s'installe, prélevée sur la réserve".
- The annex is generated from the campaign's rules (`capture_seconds`, `logistics_output`, `repairs_per_mission`, `counter_attack`), with the counter-attack said for the zones it concerns ("Poti touche les deux camps : personne ne la prendra d'office").
- Nothing overflows its page: the prototype could only estimate it (no PowerPoint or LibreOffice on the build machine); find a check that holds, and a page that does not fit splits rather than shrinks.

## Done when

Tests generate the deck of a fixture campaign and read it back with python-pptx: page titles in order, the prose in its place, the facts of the state, no enemy figure, the annex from the rules; `campaign next` writes it; the MCP action returns its path.
