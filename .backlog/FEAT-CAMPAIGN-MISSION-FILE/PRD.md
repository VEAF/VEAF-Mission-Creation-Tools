# FEAT-CAMPAIGN-MISSION-FILE — a persistent campaign names its mission file, with no date

Status: ✅ done — merged in #1313 (2026-11-18), on `develop` with #1336 (2026-11-23), shipped in 6.39.0

Flight check: on the Campagne server the mission is listed as `Campagne_Oronte`, with no date, and a redeploy replaces the file.

The DCS server browser shows the mission's file name, and the persistent campaign's is too long to read: `Campaign_Northern-Syria_Mission_01_Bouclier-de-l-Oronte_20261117.miz`.
The date the build appends also changes the name at every redeploy, and each redeploy then forces edits to the server bot's `servers.yaml`, its scheduler and the calendar.
A fixed name lets a redeploy just replace the file.

## Decisions

- David, 2026-11-18: the Oronte campaign's mission becomes `Campagne_Oronte.miz`, with no date.
- `campaign.yaml` takes an optional `campaign.mission_file`; `campaign next` writes it as `mission.name` and sets `mission.date_suffix: false` in `mission.yaml`, and the build then writes `<name>.miz` in the mission folder.
- **Persistent campaigns only.** A multi-mission campaign is refused: each of its missions needs `_NoMizedit` in its file name to keep the date, time and weather the campaign fixed, and its missions are distinct files the squadron tells apart by their number. One fixed name would drop the marker and give every mission the same file.
- `mission.date_suffix: false` is a `mission.yaml` setting of its own, open to any mission. The existing alternative, a `mission.name` ending in `.miz`, was turned down: that name is resolved from the current folder rather than the mission folder, and it carries the `.miz` into the in-game mission name and the briefing deck's file name.

## Scope

| # | Ticket |
|---|---|
| 01 | [`campaign.mission_file` and `mission.date_suffix`](tickets/01-mission-file.md) |

## Out of scope

- The Oronte campaign folder: the controlling session sets the key after the merge.
- The server and its configuration (VEAF-Servers, dcs.veaf.org).
