# FIX-SOLAR-DEFAULT-POSITION — a mission keeping the default `versions.yaml` computes its sunrise at Damascus, whatever the map

Status: ✅ done — A Caucasus mission built from a `versions.yaml` without `position` gets its sunrise at the Caucasus point (07:24-07:25 on 2024-03-15, against 07:48 at Damascus), asserted on the `start_time` of the built `.miz`; no in-game check needed.

## Found

David's release note for 6.30.0: *"`campaign next` : corriger la position par défaut (Damas) du calcul solaire dans `versions.yaml`"*.
The shipped `src/defaults/mission-folder/src/versions.yaml` writes `position: {latitude: 33.5, longitude: 35.5, timezone: "Asia/Damascus"}`, and every mission folder scaffolded from it carries that position whatever its theatre.

## Measured (2026-10-15)

`WeatherInjectorWorker` on `test/veaf-tools/weather-injector/test.miz` (Caucasus), variant `time: "sunrise"`, `base_date: "2024-03-15"`:

| `position` | `start_time` written |
|---|---|
| the shipped Damascus default | **07:48** (28 095 s) |
| none | the build **aborts**: *"Time expression contains 'sunrise' but solar times not calculated"* — the default file's own comment says solar expressions are *skipped* |
| Kobuleti (41.93 N, 41.86 E), for reference | 07:24 |

24 minutes late in March, **50 minutes** in June (2016-06-01: 06:29 against 05:39 at Kobuleti).
The theatre's clock offset was already right (`theatre_offsets.py` ignores the declared timezone for a known theatre); only the latitude and longitude were Damascus.

`campaign next` is **not** affected: since FEAT-CAMPAIGN-MISSION-BRIEFING it removes `src/versions.yaml` from the mission it creates and computes `start_time` at the centre of the campaign's zones (`campaign_manager/mission_conditions.py`).
The Kolkhida missions have no `versions.yaml`.

## Decided

- With no `position`, the build computes solar times at the theatre's default point: the map centre of `theatre-defaults.yaml` (extracted from the dcs-maps calibration missions), else the centre of `theatre-bounds.yaml` (Iraq, Kola, Nevada, The Channel), converted with the theatre's projection.
  Its timezone is the nominal zone of its longitude, used only for a theatre whose DCS clock offset is not in `theatre_offsets.py` (Iraq, MarianaIslandsWWII).
- The shipped `versions.yaml` no longer declares a `position`; the block stays, commented, as an override example.
- An explicit `position` still wins. One outside the theatre's bounds (the Damascus default left in a Caucasus mission) gets a warning naming the theatre, since existing mission folders carry it written out.
- A theatre with no point at all keeps today's behaviour (a solar expression fails with its message).

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-theatre-default-position.md) | Solar times at the theatre's point when `position` is absent | ✅ |

## Definition of done

- Python test: a Caucasus mission built from a `versions.yaml` without `position` gets the sunrise of the Caucasus point written into its `start_time`, not Damascus's; an explicit `position` still wins; every theatre the projection supports has a point inside its bounds.
- Shipped default and docs (FR + EN) no longer present Damascus as the default.
- No in-game check needed: the value is the `start_time` written in the `.miz`, and the clock offset it relies on was measured in DCS (`mission-clock-is-theatre-local`).
