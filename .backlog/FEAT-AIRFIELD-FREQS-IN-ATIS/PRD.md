# FEAT-AIRFIELD-FREQS-IN-ATIS — the ATIS and the welcome brief give the airfield's own frequencies

Status: 🧑 waiting-human — code, tests and docs done; the one in-game check is R40 in `DCS-SESSION-TODO.md`

Opened 2026-10-01 by David, right after FEAT-AIRFIELD-CHANNELS-FROM-DCS: *"On pourrait utiliser
DCS.getATCradiosData dans les scripts, par exemple quand on demande l'ATIS ou les infos météo d'un
aéroport (ou quand on slot et qu'on a le message automatique de bienvenue), pour obtenir les freqs de
l'aéroport sur lequel on se trouve ?"*

## What was measured (2026-10-01)

- **`DCS.getATCradiosData` is not reachable from the mission scripts.** It lives in DCS's GUI
  environment: the Mission Editor (`MissionEditor/modules/Mission/AirdromeData.lua`) and
  `Scripts/UI/BriefingDialog.lua` call it, the VEAF scripts run elsewhere.
- **The mission-side `Airbase` object has no frequency getter**: the API schema lists `getCallsign`,
  `getRadioSilentMode`, `getRunways`, `getID`… and nothing on its radios.
- **The data already exists, checked**: `veaf_libs/data/airfield-frequencies.yaml`, captured from a
  running DCS with the editor's own logic — 396 airfields, 7 theatres, keyed by the DCS airdrome id that
  `Airbase:getID()` returns, with UHF / VHF / FM and the TACAN.

Options weighed with David: (a) render that reference into a Lua table shipped with the scripts, (b)
`net.dostring_in('gui', …)` from the mission — permission uncertain across installs, as the smoke harness
found, (c) relay through the server hook — servers only, not single player. **(a) chosen.**

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [the reference is rendered as a Lua table the scripts load](tickets/01-render-lua-table.md) | ✅ |
| 02 | [the ATIS and the welcome brief say the airfield's frequencies](tickets/02-atis-and-welcome-brief.md) | 🧑 |
| 03 | [the mission's own base channel is given beside the DCS tower](tickets/03-mission-base-channel.md) | 🧑 |

## Definition of done

- A pilot who takes a slot on an airfield, or asks its ATIS / weather from the F10 menu, reads its tower
  frequencies and TACAN — the ones the F10 view shows — in single player and on a server alike.
- `veaf-build update-dcs-data --airfield-freqs` renders the table in the same run as the reference; a
  test fails on drift, as for `veafCities.lua`.
- Lua tests on the DCS mocks; checked once in DCS (welcome brief on a slot, ATIS from the menu).
- `CHANGELOG.md`; `doc/` where the welcome brief and the ATIS are described.

## Decided: the ATIS gives both (David, 2026-10-01)

A mission whose `bases` collection carries its own frequency for an airfield (a silenced-ATC choice the
Open Training prompt no longer makes, but older missions do) would otherwise hear the DCS tower in the
ATIS and read its own plan on the kneeboard. **Both are given**: the DCS tower, and the mission's channel
when it has one for that field and it differs — named as the channel the pilot has in their presets.

That needs a second, per-mission table: the scripts do not know the mission's radio plan, so the build
hands them, per airdrome id, the `bases` channel that matches it (alias, title, frequencies), matched the
way `content airfield-channels` matches them (`airfield_channels_manager.match_existing`). See ticket 03.

## Delivered (2026-10-04)

- `veafAirfieldFrequencies.lua`, rendered by `veaf-build update-dcs-data --airfield-freqs` with the reference; loaded with the scripts (bundle and `VeafDynamicLoader.lua`), drift test beside the reference's own.
- `veafAirbases.getAtcFrequencies(veafAirbase)` and `getMissionChannel(veafAirbase)`, taking the `veafAirbase` rather than the DCS object: its `Category` is the one `veafAirbase:create` corrected, and only an airdrome is looked up — a ship's or a FARP's `getID()` is a unit id, which can collide with an airdrome id.
- `veafWeather.getAtcFrequenciesString`, appended to the ATIS and the welcome brief: bands UHF / VHF / FM, three decimals, then the TACAN.
- Ticket 03: the build writes `veafAirbases.MissionChannels` into `veaf-config.lua` (`airfield_channels_manager.mission_channels`, matched by `match_existing`). The mission channel is named by its **title** rather than its alias, the ticket's example notwithstanding: the title is what the pilot's presets and kneeboard show. A channel that only repeats bands of the tower (same values, or a subset) adds no line.
- David, 2026-10-04, after review: a tower the mission silenced (`getRadioSilentMode()`) gives way to the mission channel, which is then the only line; with no mission channel for the field (the common case) the DCS frequency is still given.
- Left: the in-game check, R40 in `DCS-SESSION-TODO.md`.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the ATIS and the welcome brief give the airfield's own frequencies.** David, 2026-10-01, after FEAT-AIRFIELD-CHANNELS-FROM-DCS. `DCS.getATCradiosData` is not reachable from the mission scripts and `Airbase` has no frequency getter, so the captured reference is rendered as a Lua table loaded with the scripts (the `veafCities.lua` model); the welcome brief and the ATIS add the tower and TACAN, and — David's decision — also the mission's own `bases` channel when it differs. Three tickets
