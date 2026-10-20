# 04 — Presets: 4 aircraft injected, a report that is not there

Status: ⬜ ready

On the sandbox mission (5 dynamic-slot templates pulled: A-10C II, F-15C, F-16CM, AH-64D, UH-1H; `set_airfield_channels` for Incirlik and Hatay):
- every build said "injected presets into 4 aircraft" for 59 aircraft groups;
- "Validation report written to …\presets-validation-report.md (0 issues found)", and the file was then empty, then absent;
- in the built `.miz`, the A-10C II template's frequency was 122.1 (Incirlik's VHF channel) and the AH-64D's 122.1.

Investigate before fixing — the AI had edited `presets.yaml` by hand (truncated once, restored), so part of this may be its doing.
Rebuild the same mission from a clean scaffold through the actions only, and measure each of the three points.
A real defect is fixed here; a non-defect is written down in this ticket with its measurement.

## Measured 2026-10-20 — not a defect of the tools

The sandbox mission rebuilt from a clean folder through the actions only: `scaffold_mission` (standard, Syria, 6.31.1 from the release), `set_airbase_coalition` Incirlik and Hatay, `set_airfield_channels` Incirlik and Hatay, `add_farp` "FARP Azaz" (the sandbox's own parameters), `build_mission`.

| Point | Clean folder | Explanation |
|---|---|---|
| "injected presets into 4 aircraft" | 44 aircraft out of 173 groups with the whole shipped catalogue; of the sandbox's five types, exactly four get presets: the blue A-10C II, AH-64D, UH-1H and F-16CM templates. The F-15C has no preset radio, and the red templates match no assignment of the shipped `presets.yaml` | 4 is what the five types give; the other 55 groups of the sandbox were AI aircraft |
| "0 issues found", then an empty or absent report | `presets-validation-report.md` written, 12 issues, all on types the sandbox did not keep (F4U-1D…) | `generate_validation_report` always writes a header and a verdict; the empty and absent file came from the AI's shell commands, not from the build |
| A-10C II and AH-64D on 122.1 | 131.0, channel 1 of the shipped VHF list | the AI replaced the `primary_2` list with `01: Base-Incirlik` (tool call #152 of the export); a group's frequency is channel 1 of its first radio, so 122.1 is Incirlik's VHF as asked |
