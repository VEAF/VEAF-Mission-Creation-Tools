# CHORE-VENDOR-CTLD-RC17 — take CTLD 2.0.0-rc17

Status: ✅ done — 2026-11-05

`published-v2.0.0-rc17` shipped on 2026-11-05, ahead of the next VMCT release.
A verbatim sync, done the way `CHORE-VENDOR-CTLD-RC16` did it, with nothing else to adapt.

## What rc17 changes in the engine

- **A piloted Fat Cow leaves its FARP open** when it takes off, is shot down, or its pilot leaves; **Pack the Fat Cow FARP**, from any piloted CH-47 landed within 150 m, sets what is left down as crates.
- **Load** sets a loadout's crates down next to the CH-47 instead of putting them in the hold; **Deploy the Fat Cow FARP** takes the cow crates out of the hold. Each open FARP has its own name.
- Fixed: an aeroplane no longer gets the Fat Cow menu.
- The JTAC logs its laser code, radio and each spot it lases in `dcs.log`.

No new setting, no catalogue change: the diff against rc16 adds no top-level `ctld.*` setting and leaves `ctld.configListSince` and the embedded catalogue (`2.3.0`) as they were, so `validate` and `ctld-upgrade` need nothing.

## Measured

- The vendored file is the published asset with its line endings normalised (CRLF → LF), 1 390 149 bytes, SHA-256 `1f40a79e6ba54653…`; `ctld.VERSION` reads `2.0.0-rc17`.

## Definition of done

- `src/scripts/community/CTLD.lua` is the rc17 asset verbatim, in LF.
- `vendored.yaml` pins `2.0.0-rc17` and watches `published-v2.0.0-rc17`.
- The whole Lua and Python suites green.
- `CHANGELOG.md` under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The rc17 file has not been flown from this repository.
