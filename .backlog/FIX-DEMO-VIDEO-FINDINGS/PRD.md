# FIX-DEMO-VIDEO-FINDINGS — what the AI worked around while building the demo video's mission

Status: ⬜ ready

Origin: David's demo video, 2026-10-22, recorded on a fresh Windows sandbox with OpenCode and DeepSeek V4.1 Flash on VMCT 6.31.3.
The AI built an objective mission on GermanyCW ("Cut the Werra Bridge": 2 A-10C II, 2 AV-8B, 2 F-16C, 2 UH-1H in dynamic slots, E-3A and KC-135 support) and, in its final report, listed what the tools made it work around.
The five points below are its words, read off the video (around 5:06); none is measured yet.
The mission folder (`Documents\test-mission-1` on the sandbox) is the reproduction case if David keeps it; otherwise each ticket rebuilds the case from a clean scaffold on GermanyCW.

| # | What the AI reported | Ticket |
|---|---|---|
| 1 | "the tools reject `Texaco` as a Tanker callsign family" — the KC-135 became `Enfield` | 01 |
| 2 | "the packer refuses 123.5 MHz for the UH-1H radio" — the Huey flight got 250.700 | 02 |
| 3 | "with dynamic slots the deck has no flight list" — it wrote `tools/patch-ato.ps1` to fill the ATO page, to re-run after every `build_mission_briefing` | 03 |
| 4 | "Deck's Support line and tactical map only pick up the AWACS"; `inspect_built_mission` "support" lists only Overlord, while the tanker is in the `.miz` (Tanker task, TACAN 63Y, 262 MHz, orbit) | 04 |
| 5 | "`build_mission` overwrites the .miz and wipes briefing pictures → always run `build_mission_briefing` last" | 05 |

Each ticket measures first: a non-defect (DCS behaviour, a misuse the guide should prevent) is written down in its ticket with the measurement, and fixed in the guide or the known limitations instead of the code.

## Tickets

- [01 — "Texaco" refused for a tanker](tickets/01-texaco-tanker-callsign.md)
- [02 — 123.5 MHz refused on the UH-1H](tickets/02-uh1h-123-5.md)
- [03 — The ATO page is empty with dynamic slots](tickets/03-ato-dynamic-slots.md)
- [04 — Support: only the AWACS, the tanker forgotten](tickets/04-support-misses-the-tanker.md)
- [05 — `build_mission` wipes the briefing pictures](tickets/05-build-wipes-briefing-pictures.md)
