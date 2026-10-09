# 08 — The server rewrote the mission's date, time and weather

Status: 🧑 waiting-human
Type: config + fix

## Found

David, 2026-10-09: "la météo en vol n'était pas du tout celle prévue au briefing (plafond à +/- 10000ft, 5-7 octas à vue de nez)".

The mission's four copies, read on 2026-10-09 (`mission` member of each `.miz`):

| copy | date | start | clouds |
|---|---|---|---|
| built, `missions/mission-01/mission/Kolkhida_20261008.miz` | 2016-06-01 | 22 140 s (06:09) | density 0, base 2 000 m, no preset |
| as uploaded, server `DCS.missions\.dcssb\Kolkhida_20261008.miz.orig` (20:19) | 2016-06-01 | 22 140 s | density 0, base 2 000 m, no preset |
| rewritten, `DCS.missions\.dcssb\Kolkhida_20261008.miz` (20:37) | **2026-10-08** | 31 380 s (08:43) | **`preset = "Preset18"`, base 3 000 m** |
| served, `DCS.missions\Kolkhida_20261008.miz` (21:23) | **2026-10-08** | — | **`Preset18`, base 3 000 m** |

So VMCT built and shipped the CAVOK sky the briefing announced; the server replaced it.
A base of 3 000 m is the ~10 000 ft ceiling David saw, and a cloud preset rather than a density is what makes it 5–7 octas.

The cause is DCSServerBot's configuration on dcs.veaf.org (`C:\Users\veaf\VEAF-DCSServerBot\config\nodes.yaml`, read-only): **every one of the six instances** has `RealWeather: enabled: true` with `date: { enable: true, system-date: true }`, and the MizEdit setting `MatinTôt/Météo/Réelle/adaptée` (`presets.yaml`: `Moment/MatinTôt` = `start_time: morning - 01:30`, plus the real weather, adapted).
No instance escapes it: `foothold1` has `mission_rewrite: false`, which only makes the bot stop the server to rewrite instead of rewriting in place.

**The `ICAO_xxxx` suffix picks the station, it does not switch RealWeather on.**
David remembered that a mission must end in `ICAO_xxxx`; the bot's extension (`VEAF-DCSServerBot\extensions\realweather\extension.py`, `get_icao_code`) reads the four letters after `ICAO_` in the file name and uses them as the METAR station.
Without them it falls back to the station of RealWeather's own `config.toml` (`realweather_v2.1.0\config.toml`: `icao = "UGKO"`), and skips only when that one is empty too.
So `Kolkhida_20261008.miz` was rewritten from Kutaisi's METAR (`private1_server\Missions\realweather.log`, 21:23:17 local: `METAR UGKO 081900Z 25011KT 9999 SCT033CB BKN048`), the preset `Météo/Réelle/adaptée` raised the base to its `minimum: 3000`, and RealWeather picked `Preset18` at 3 000 m.
Naming the mission `…_ICAO_UGSB` would have taken Batumi's sky instead of Kutaisi's — still not the campaign's.

What it costs a campaign: the weather, the date and the hour the campaign fixes (`CAMPAIGN.md`, *date, time and weather*) do not reach the players, the briefing announces a sky they will not see, and October replaces June (sun, season).
What it does not cost: the campaign's own date — `campaign apply` keeps `2016-06-01` in `campaign-state.yaml`, not the server's.

## What the bot allows

Read on 2026-10-09 in the bot's code, `C:\Users\veaf\VEAF-DCSServerBot`. Two separate rewrites hit the mission, and they are switched off differently.

| rewrite | where | can it skip a mission? |
|---|---|---|
| MizEdit preset `MatinTôt/Météo/Réelle/adaptée` (the hour, and RealWeather through its `Météo/Réelle/adaptée` part) | `extensions\mizedit\extension.py`, `beforeMissionLoad` | **yes**: `filter:` is a regular expression searched in the file name (`re.search`); a mission it does not match is left alone, so a negative look-ahead excludes by name |
| the instance's RealWeather extension | `extensions\realweather\extension.py`, `beforeMissionLoad` | **no filter**: it runs whenever it finds a station, in the file name (`ICAO_xxxx`) or in its `config.toml` (`UGKO`) |

The MizEdit preset runs RealWeather itself (`apply_presets`), loading the extension even when the instance has it disabled.
So with the instance-level RealWeather off, the other missions keep their real weather through MizEdit.

## To do

A configuration need first (David, 2026-10-09); the only code is the name `campaign next` gives the mission, so that one server rule covers every campaign.
The server's administrators make the change; nothing is edited from here.

- **Decided by David (2026-10-09): a campaign mission is named `Campaign_<campaign>_Mission_<NN>_<title>_NoMizedit`, and the server's MizEdit ignores every mission whose name carries `_NoMizedit`.**
  - `campaign next` writes that name into the mission folder's `mission.yaml` (`mission.name`), `NN` on two digits.
    The build then appends its date (`commands/build.py`: a bare name becomes `<name>_<YYYYMMDD>.miz`), so the file is `Campaign_Kolkhida_Mission_02_<title>_NoMizedit_20261015.miz`: the marker is **not** at the end, and the server's filter must look for it anywhere in the name.
  - `<title>`: the mission's title once Claude has designed it, ASCII letters, digits and `-` only (no space, no accent — the build keeps both, and an `é` in a server path already cost a glob over SFTP); no title yet, no `_<title>` part.
    It must never contain `ICAO_`.
  - Tests on the name `campaign next` writes; `CAMPAIGN.md` FR + EN.
- On the server, every instance that may fly a campaign mission (`nodes.yaml`, administrators only):

  ```yaml
          RealWeather:
            enabled: false                   # no filter of its own; the MizEdit preset still runs it for the other missions
          MizEdit:
            filter: '^(?!.*_NoMizedit)'      # every mission whose name does not carry _NoMizedit
  ```

  Both lines are needed: the name only reaches MizEdit, while the instance-level RealWeather has no filter and would still rewrite the mission from `UGKO`.
  To check once on the server, since only the code was read: a rotation mission still gets real weather, and a `_NoMizedit` mission is served identical to its `.miz.orig` (date, `start_time`, `weather`).
- In `CAMPAIGN.md` (FR + EN), one paragraph: a server that rewrites missions (DCSServerBot RealWeather or MizEdit) replaces the campaign's date, time and weather, and the `ICAO_xxxx` suffix only picks the station; say what to ask of the server.

## Done when

The instance that will fly *Kolkhida* mission 2 serves it with the date, time and sky the campaign built, read in the served `.miz` against the `.orig`.

## Left (2026-10-09)

`campaign next` writes the name, and `CAMPAIGN.md` says what to ask of the server.
Left: the server's administrators set the MizEdit filter and switch the instance-level RealWeather off; then mission 2 served identical to its `.orig`.
