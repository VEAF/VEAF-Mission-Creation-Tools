# FEAT-TERRAIN-DATA-DOWNLOAD — terrain data an AI can use without DCS

Status: 🔄 in progress

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

1. [01 — download a missing grid on first use](tickets/01-download-on-first-use.md)
2. [02 — `veaf-build terrain-data`: publish the grids](tickets/02-publish-command.md)
3. [03 — docs, known limitations, changelog](tickets/03-docs.md)
4. [04 — sweep the missing theatres and publish the release](tickets/04-sweep-and-publish.md) · 🧑 David runs DCS and gives the go to publish
