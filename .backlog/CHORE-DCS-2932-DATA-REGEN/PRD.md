# CHORE-DCS-2932-DATA-REGEN — regenerate the GermanyCW data that predates DCS 2.9.32

Status: 🧑 waiting-human — the data is regenerated (2026-11-26); waits for the two in-game checks of R55 in `DCS-SESSION-TODO.md`

David moved to DCS 2.9.32.30490 on 2026-11-26. The repository data is pinned on 2.9.30.28536. Two release-note studies (2.9.32, then 2.9.31 = build 29434, which has no terrain section) found three GermanyCW data sets that predate 2.9.32; [FEAT-AIRDROMES-DUMP-UNION](../FEAT-AIRDROMES-DUMP-UNION/PRD.md) already recaptured the airfields and the parking stands.
Decision (David, 2026-11-26): one lot, one PR.

## Scope

1. **Cities** — `update-dcs-data --cities` from the local install (no DCS running).
2. **Airfield frequencies** — `update-dcs-data --airfield-freqs --capture --theatre GermanyCW` (DCS running, David). Expected: Targa HF 5.0 → 4.6 MHz (`Radio.lua`: 4 600 000 Hz) and the 20 new airfields.
3. **Clear-ground catalogue** — sweep GermanyCW again (DCS running, David); compare entries and weight before and after, keep the weight ceiling if FEAT-CLEAR-GROUND-COVERAGE sets one.
4. **Two in-game checks** written as `DCS-SESSION-TODO.md` items: the coalition of a killed static (2.9.31 « Wrong attribution of coalition on kills of statics and S_EVENT_KILL missing in some cases ») and the radio presets after « Prepare Mission » (2.9.31 « Prepare Mission stores unchangeable radio presets »). A measurement goes to `known-limitations.yaml` (`kind: dcs`, dated, with its value); no measurement, nothing written there.

Out of scope: Kola (captured on another machine, its own lot).

## Done when

The three GermanyCW data sets come from 2.9.32, the generated files and their tests agree, the changelog says so, and the two checks wait in `DCS-SESSION-TODO.md`.
No code changes unless a step proves one necessary; if so the full `pr-code-review` applies.
