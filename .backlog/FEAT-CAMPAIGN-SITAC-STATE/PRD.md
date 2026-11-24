# FEAT-CAMPAIGN-SITAC-STATE — the campaign's state file carries what a web map needs

Status: ✅ done — merged in #1309 (2026-11-18), on `develop` with #1336 (2026-11-23), shipped in 6.39.0; the reader is `VEAF/foothold-sitac` #148 (2026-11-18)

Flight check: the web map `foothold-sitac` draws the Campagne server's live `persistent.state` (zones, connections, convoys, credits and stock).

VEAF's web map `foothold-sitac` (VEAF/foothold-sitac, FastAPI + Leaflet) draws Foothold's save files.
David wants it to draw the VEAF persistent campaigns as well ("Bouclier de l'Oronte" on the Campagne server), rather than a new tool (2026-11-18).

The campaign writes `Saved Games\<server>\Missions\Saves\<campaign>\persistent.state`, a Lua literal `return { ... }`.
It holds what the next mission depends on — owners, garrisons unit by unit, captures, buildings — but not where the zones are, how they connect, nor what kind they are: those come from the mission's data table, which the map cannot read.

## Decisions (David, 2026-11-18)

- The map's data goes into the existing state file, as a `sitac` block; no second file.
- The garrison is written as counts only (alive / total): the intelligence rule hides a garrison's composition until it is reconnoitred, and the map is public.
- One PR per repository: this one into `feature/dynamic-campaign`, the reader in `foothold-sitac`.

## Scope

| # | Ticket |
|---|---|
| 01 | [The state file carries a `sitac` block](tickets/01-sitac-block.md) |

## Out of scope

- The reader and the map: `foothold-sitac`, its own pull request.
- The deployment on the server: after the merges, by David.
