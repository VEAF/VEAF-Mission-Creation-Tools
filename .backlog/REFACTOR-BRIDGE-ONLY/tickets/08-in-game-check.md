# 08 — In-game check

Status: ✅ done

In David's DCS (`C:\jeux\DCS World`): `recon-plan` and `recon-shoot` on a shooting copy, `mission-check` on a test copy, `smoke-test`, one theatre of the airfield frequency capture.

## Result

2026-10-29, 12:01–12:10 (Paris), David's DCS, `VEAF_Syria_MarteauDuGolan_RECON_BRIDGE.miz` (the shooting copy written by `recon-prepare`), through a `dcs-serve` another session had started (`--config`):

- `recon-plan`: 8 shots written from the live units;
- `mission-check`: PASS, 16 checks (147 menu entries, 10 zones, 2 routed columns moving, 4 CAP variants);
- `smoke-test`: 9/9, the four `Disposition` checks and the coalition submenu — formerly hook checks — included;
- the airfield capture chunk sent to the `gui` state: Syria, 224 airdromes, 81 from radio and 143 without — identical to the committed `Syria.json`;
- `recon-shoot --only 02-contreattaque`: the F11 camera moved through `export`, the window grabbed, `recon-render` made the photo.

The first attempt to load the copy failed on two La-7 templates whose frequencies (118.6 / 121.5 MHz) are outside the La-7's 3.7–6.06 MHz radio — a defect of the shipped templates, not of this lot, handled in its own session.
