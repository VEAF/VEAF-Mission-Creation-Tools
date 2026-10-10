# 01 — A campaign mission's date, time and weather, fixed and moving on

Status: ✅ done

David, 2026-10-07: one mission and no variant; date, time and weather fixed; weather may change between missions but the ground stays visible; "c'est à toi de fixer la date et l'heure en fonction de l'avancée de la campagne".

- `campaign.yaml` may give a start date and a default time (`start_date`, `start_time`, a clock time or a solar expression such as `sunrise+30*60`); the campaign state keeps the date of each mission.
- `campaign next` sets the next mission's date (the day after the last one by default) and time, computing a solar expression for the campaign's ground — the centre of its zones — and the mission's date, with the theatre's time zone.
- It draws the weather within ground-visible limits (clouds few or scattered at most, visibility 8 km or more, no fog, rain light at most), seeded so that a refresh of the same mission gives the same weather.
- The folder it creates has `pipeline.weather: false` and no `src/versions.yaml`; the `pipeline:` block goes at the end of `mission.yaml`, where it swallows nothing (written in the middle, it took two module entries as its own on 2026-10-07).
- Claude may set another time or weather afterwards (`set_mission_date`, `set_weather`); a refresh keeps what was set.

## Done when

Tests: the date advances mission after mission; a solar time is computed for the campaign's ground, not Damascus; a drawn weather always passes the ground-visible limits (enumerated over seeds); the created folder has no variant step; a refresh does not redraw.
