# FEAT-TERRAIN-DATA-DOWNLOAD — terrain data an AI can use without DCS

Status: ✅ done — merged 2026-10-20 (#1154 and the TheChannel follow-up); the `terrain-data` release holds 11 theatres: Afghanistan, Caucasus, Falklands, GermanyCW, MarianaIslands, MarianaIslandsWWII, Normandy, PersianGulf, SinaiMap, Syria, TheChannel. Kola, Iraq and Nevada are not installed on David's PC. · archived 2026-11-24

## Origin

David, 2026-10-20: the elevation maps and everything we look up in DCS are not shipped; publish them on GitHub and have the exe fetch them.

The need: an AI assistant answering terrain questions (`describe_terrain`, `terrain_elevation`, the surface checks of every placement) on a PC where DCS is not open — a Windows sandbox for a demo video, or another mission maker's PC.
Today no elevation grid ships with veaf-tools: by the 2026-10-01 decision (FEAT-TERRAIN-ELEVATION) each workstation sweeps its own with `veaf-tools dcs terrain-sweep`, into `~/.veaf/terrain/<Theatre>.terrain`.

**Decision (David, 2026-10-20): publish the grids — heights sampled from ED's maps — on GitHub, and have the exe download them.**

## What exists (measured on David's PC, 2026-10-20)

| theatre | grid in `~/.veaf/terrain` | clear-ground catalogue |
|---|---|---|
| Falklands | 4.2 MB | — |
| Normandy | 1.2 MB | — |
| PersianGulf | 10.0 MB | — |
| SinaiMap | 4.9 MB | — |
| Syria | 5.3 MB | — |
| Caucasus | — | shipped in the exe (252 kB) |
| GermanyCW | — | shipped in the exe (309 kB) |
| MarianaIslands, MarianaIslandsWWII, TheChannel, Afghanistan | — (installed, never swept) | — |
| Kola, Iraq, Nevada | — (not installed) | — |

25.6 MB of grids in all.
The local clear-ground folder holds the same two catalogues as the exe, nothing more: there is no catalogue to publish.

## Approach

- A GitHub release of its own, tag `terrain-data`, separate from the tools' releases so 26 MB is not re-published with every version.
  One asset per theatre (`<Theatre>.terrain`) and a manifest (`terrain-data.json`: per theatre, file name, size, SHA-256).
  Created **not latest** (`--latest=false`): `update_checker` reads `/releases/latest`, and a `terrain-data` tag there would silence the new-version warning for everybody.
- `grid_for_theatre` downloads a missing theatre on first use into `~/.veaf/terrain`, checks its size and SHA-256 against the manifest and that it loads as that theatre's grid, then uses it.
  A grid already there — swept on the workstation or downloaded before — is used as is, never replaced.
  Offline, or any download failure: today's answer (the "sweep it in DCS" message), and no second try in the same process.
- Downloads go through the updater's trusted-host and redirect-walk checks, moved to `veaf_libs` so both share one copy.
- Publication: a `veaf-build terrain-data` subcommand checks each grid, writes the manifest and creates or updates the release; documented in `doc/developer/` (fr + en).

## Tickets

1. [01 — download a missing grid on first use](FEAT-TERRAIN-DATA-DOWNLOAD.md)
2. [02 — `veaf-build terrain-data`: publish the grids](FEAT-TERRAIN-DATA-DOWNLOAD.md)
3. [03 — docs, known limitations, changelog](FEAT-TERRAIN-DATA-DOWNLOAD.md)
4. [04 — sweep the missing theatres and publish the release](FEAT-TERRAIN-DATA-DOWNLOAD.md)
5. [05 — TheChannel can be swept](FEAT-TERRAIN-DATA-DOWNLOAD.md)

## Tickets, in full

## 01 — download a missing grid on first use

Status: ✅ done

Files: `veaf_libs/github_download.py` (new: trusted-host check and redirect walk, out of `veaf-tools-updater.py`), `veaf-tools-updater.py` (imports them), `veaf_libs/terrain_elevation.py`, `veaf_mission_mcp/terrain.py` and `surface.py` (the "no grid" message), tests.

### Done when

- A theatre with no local grid is fetched from the `terrain-data` release, checked (size, SHA-256, loads as that theatre) and written atomically to `~/.veaf/terrain`; the next call reads the local file.
- A local grid is never downloaded over.
- Offline, an unknown theatre, a bad checksum, an untrusted redirect or an oversized answer: `None`, the file system untouched, one attempt per process.
- The updater's tests pass unchanged against the moved helpers.

## 02 — `veaf-build terrain-data`: publish the grids

Status: ✅ done

Files: `veaf_build/cli.py` (the subcommand), a small module for the manifest, tests, `doc/developer/` (a new page, fr + en, in the `nav`).

### Done when

- `veaf-build terrain-data <dir>` loads every `*.terrain` of the folder, refuses one whose header names another theatre, writes `terrain-data.json` and shows what it would upload with the sizes.
- With `--publish`, it creates the `terrain-data` release (not latest) when missing and uploads the grids and the manifest with `--clobber`.

## 03 — docs, known limitations, changelog

Status: ✅ done

Files: the mission-maker pages that say a grid is swept per workstation (`GUIDE`, `AI_ASSISTANT_CATALOG`, `CAMPAIGN`, `CLI_REFERENCE`, fr + en), `known-limitations.yaml` (the Falklands and MarianaIslands entries say "not shipped") (the generated `docs/agents/dcs-runtime-traps.md` renders only the `dcs` entries, so it does not change), `CHANGELOG.md`.

### Done when

- The pages say a grid is downloaded when published, swept otherwise; `poetry run docs-check` passes.
- The limitations say the grid is downloaded where published, and a new entry says a downloaded grid is never refreshed.

## 04 — sweep the missing theatres and publish the release

Status: ✅ done

David runs DCS: `veaf-tools dcs terrain-sweep` for Caucasus, then GermanyCW, MarianaIslands, MarianaIslandsWWII, TheChannel and Afghanistan if his licences open them (Kola and Iraq are not installed on his PC).

Publishing is an outward action: the asset list and sizes are shown, and the release goes out on David's explicit go.

### Done when

- The `terrain-data` release holds at least the five existing grids, and Caucasus once swept.
- `gh api repos/VEAF/VEAF-Mission-Creation-Tools/releases/latest` still answers the tools' release.
- `describe_terrain` answers on a PC with no local grid.

### Measured (2026-10-20)

| theatre | cells | sweep | file | ground |
|---|---|---|---|---|
| Caucasus | 26.5 M | 4 min 25 | 3.6 MB | 0–5 565 m |
| GermanyCW | 10.2 M | 3 min 46 | 4.0 MB | 0–1 524 m |
| MarianaIslands | 33.3 M | 5 min 33 | 31 kB | 0–1 015 m |
| MarianaIslandsWWII | 20.8 M | 3 min 28 | 26 kB | 0–969 m |
| Afghanistan | 35.4 M | 6 min 45 | 18.8 MB | 0–7 975 m |
| TheChannel | 0.8 M | 16 s | 304 kB | 0–274 m |

Some 1.5 s per batch of 20 000 heights was announced; measured, about 0.2 s. A sweep started while the previous survey mission still ran stops at once ("the running mission is on GermanyCW"): start it once the new mission is loaded.
On an empty `VEAF_HOME`, `describe_terrain` downloaded Syria (4.6 s), Caucasus (7.0 s) and MarianaIslands (4.3 s) and answered.

## 05 — TheChannel can be swept

Status: ✅ done

`terrain-sweep TheChannel` answered "Unsupported theatre": TheChannel had no entry in `theatre-defaults.yaml`, so no survey mission could be written, and VEAF/dcs-maps has no calibration mission for it.
Added as Falklands was (2026-10-13): map centre in the middle of its 12 airfields' extent (`airdrome-positions.yaml`, converted with the theatre's projection), bullseyes at the origin.
The survey mission loaded and the sweep covered the extent DCS gave, `-130000,-115000,75000,130000`.
