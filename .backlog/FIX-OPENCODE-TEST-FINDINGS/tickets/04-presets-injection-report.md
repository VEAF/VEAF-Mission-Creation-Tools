# 04 — Presets: 4 aircraft injected, a report that is not there

Status: ⬜ ready

On the sandbox mission (5 dynamic-slot templates pulled: A-10C II, F-15C, F-16CM, AH-64D, UH-1H; `set_airfield_channels` for Incirlik and Hatay):
- every build said "injected presets into 4 aircraft" for 59 aircraft groups;
- "Validation report written to …\presets-validation-report.md (0 issues found)", and the file was then empty, then absent;
- in the built `.miz`, the A-10C II template's frequency was 122.1 (Incirlik's VHF channel) and the AH-64D's 122.1.

Investigate before fixing — the AI had edited `presets.yaml` by hand (truncated once, restored), so part of this may be its doing.
Rebuild the same mission from a clean scaffold through the actions only, and measure each of the three points.
A real defect is fixed here; a non-defect is written down in this ticket with its measurement.
