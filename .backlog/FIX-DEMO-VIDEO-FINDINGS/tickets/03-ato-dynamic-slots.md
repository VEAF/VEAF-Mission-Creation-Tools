# 03 — The ATO page is empty with dynamic slots

Status: ✅ done

The AI: "ATO page is completed by script: with dynamic slots the deck has no flight list, so `tools/patch-ato.ps1` writes the four flights, aircraft and frequencies into it (re-run after every `build_mission_briefing`)".
The objective prompt says that with dynamic slots "the ATO keeps the callsigns with empty pilot boxes" — so the ATO is expected to list the flights, and `build_mission_briefing` apparently builds it only from groups with player slots.

The final deck (video, page 4) shows what the AI's script produced: one block per base ("Dynamic slots - Spangdahlem: A-10C II (Archer, 250.100) - AV-8B (Nickel, 250.300) - F-16C (Ninja, 250.500)"), four pilot boxes, "Free loadout".

Measure on a clean GermanyCW mission with dynamic slots only: what page 2 of `docs/briefing.pptx` holds.
Fix: the ATO of a dynamic-slot mission lists its flights — from the dynamic-slot templates, their callsigns and frequencies, and the bases offering them — with empty pilot boxes, so no AI has to patch the deck.

Done when: a dynamic-slot mission's ATO page lists its flights, with a test on the built deck.

## Result

Fix: `mission_reader.slot_flights` reads, for each base of the side that offers dynamic slots, the types linked to one of its templates (`linkDynTempl` of the warehouse entry) and, for each, the first named channel of its first radio (`A-10C_2 — Archer : 390.0 MHz`); `ato_page` lists them under the airfield's "dynamic slots" line, before the empty pilot boxes. Tests: `TestDynamicSlotAto` (a linked template is listed with its channel; a base linking none lists no type).
