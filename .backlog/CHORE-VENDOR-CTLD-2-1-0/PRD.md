# CHORE-VENDOR-CTLD-2-1-0 — take CTLD 2.1.0

Status: ✅ done — 2026-11-23

`published-v2.1.0` shipped on 2026-11-23, with the fixes the BFR team (Sharko) asked for to move to v6; VMCT 6.39.0 waits for it.
VMCT was still on `2.0.0-rc17`; `published-v2.0.0` (2026-11-07) is the rc17 code published as stable and was never vendored on its own.
A verbatim sync, done the way `CHORE-VENDOR-CTLD-RC17` did it.

## What 2.1.0 changes in the engine

Several CTLD 1.x behaviours come back, three of them as new defaults:

- **Dropped groups act on their own**: troops and vehicles dropped by a pilot, by parachute or by an AI transport go for the nearest enemy within `maximumSearchDistance` (default 3000 → 4000 m), otherwise walk to a random point within the new `maximumMoveDistance` (2000 m). Both at `0` keep them where they are dropped.
- **Players can drive what CTLD creates** (Combined Arms, game masters); the new `spawnedUnitsPlayerCanDrive: false` gives back the 2.0.0 behaviour.
- **An inactive `troopZones` / `wpZones` entry stays inactive** until it is activated.
- A SAM system's group is named `<type>_CTLD_AA_<id>`, no longer `<type>_CTLD_AA_<second>`.
- New `forbidUnpackInLogisticZone` (off): the CTLD 2 replacement of v1's `minimumDeployDistance`, which CTLD 2 does not read.
- Pack and unpack create the new object before removing the old one; parachuted troops keep their weapons; SAM repair crates are back in **Request Equipment**; several Fat Cow fixes; `ctld.unloadTransport` and `ctld.unloadInProximityToEnemy` work again.
- The labels of the configuration follow its own `i18n_lang` (VEAF/CTLD#310), which closes VMCT #1307: `GUIDE.md`'s « your explicit setting wins » is now true of the labels too.
- Four new events (`OnTroopsLoaded`, `OnTroopsUnloaded`, `OnTroopsExtracted`, `OnTroopsReturned`): 51 in all, against 47.

## The catalogue moves to `2.5.0`

The embedded catalogue (`ctld.configDefault`) goes from `2.3.0` to `2.5.0` with three new scalar settings in `mm_facing`: `forbidUnpackInLogisticZone`, `maximumMoveDistance`, `spawnedUnitsPlayerCanDrive`.
`ctld.configListSince` does not move: no new list, so nothing in `find_catalogue_gap` / `upgrade_to_catalogue` changes.
VMCT reads the catalogue from the vendored file, so the new keys reach `prepare`, `validate` and `ctld-upgrade` with no code change.

| mission | effect |
|---|---|
| no `ctld-config.yaml` | CTLD runs on its embedded defaults → the three new behaviours, search at 4000 m |
| scaffolded by `prepare` from now on | the 2.5.0 catalogue is copied in → same |
| existing `ctld-config.yaml` (`2.3.0`) | CTLD gives the three new settings their default; it keeps its own `maximumSearchDistance` (3000); `validate` warns, `ctld-upgrade` writes the three settings in |

The BFR study noted that `maximumMoveDistance` and `minimumDeployDistance` had no key in `ctld-config.yaml`: the first now has one, the second is replaced by `forbidUnpackInLogisticZone`.

## Measured

- The vendored file is the published asset with its line endings normalised (CRLF → LF), 1 424 710 bytes, SHA-256 `ebad458d7f813a4b…`; `ctld.VERSION` reads `2.1.0`.
- No VEAF Lua module calls a CTLD function 2.1.0 changes (`ctld.initialize`, `ctld.gs`, `ctld.tr` only), and nothing in this repository looks for `_CTLD_AA_` group names.
- `known-limitations.yaml`: no CTLD entry is fixed by 2.1.0.

## Definition of done

- `src/scripts/community/CTLD.lua` is the 2.1.0 asset verbatim, in LF.
- `vendored.yaml` pins `2.1.0` and watches `published-v2.1.0`.
- `test_ctld_catalogue_gap.py` follows the catalogue to `2.5.0` and covers the three new settings on a `2.3.0` file.
- `custom-script-layer` (FR + EN) gives the new event count; `GUIDE` (FR + EN) names the three default changes, kept as they are (David, 2026-11-23: « Oui, les trois »).
- The whole Lua and Python suites green.
- `CHANGELOG.md` under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The 2.1.0 file has not been flown from this repository.
