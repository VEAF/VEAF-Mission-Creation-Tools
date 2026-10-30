# CHORE-VENDOR-CTLD-RC16 — take CTLD 2.0.0-rc16

Status: ✅ done — 2026-10-30

`published-v2.0.0-rc16` shipped on 2026-10-30, ahead of the next VMCT release.
A verbatim sync, done the way `CHORE-VENDOR-CTLD-RC15` did it, with nothing else to adapt.

## What rc16 changes in the engine

- **An AI Fat Cow that loses its flight can be taken over**: when its flight is shot down or its last player leaves, it flies home, and **F10 → CTLD → Fat Cow → Take over a Fat Cow** lists the cows on their way home, nearest first.
- **Release the Fat Cow**, next to **RTB**: the cow leaves the flight and stays where it is for another flight to take over.
- Fixed: an AI Fat Cow sent home from the ground no longer vanishes on the spot; it no longer lands into trees; one killed without DCS reporting its death is forgotten within 10 s.

No new setting, no catalogue change: `ctld.configListSince` and the embedded catalogue (`2.3.0`) are those of rc15, so `validate` and `ctld-upgrade` need nothing.

## Measured

- The vendored file is the published asset with its line endings normalised (CRLF → LF), 1 381 010 bytes, SHA-256 `25b5a9e1402ccaee…`; `ctld.VERSION` reads `2.0.0-rc16`.
- The diff against rc15 adds no top-level `ctld.*` setting.

## Definition of done

- `src/scripts/community/CTLD.lua` is the rc16 asset verbatim, in LF.
- `vendored.yaml` pins `2.0.0-rc16` and watches `published-v2.0.0-rc16`.
- The whole Lua and Python suites green.
- `CHANGELOG.md` under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The rc16 file has not been flown from this repository; its release notes say the fixes after the 2026-10-26 evening have not been flown yet either.
