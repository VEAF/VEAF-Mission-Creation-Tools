# 03 — The AWACS holds well behind the front

Status: ✅ done
Type: fix

## To do

- First, a failing test (`test/lua/test_veafSupport.lua`): with a red zone carrying only MANPADS 50 km from the AWACS's Mission Editor orbit, the AWACS's station is at least `awacs_standoff` from **every** red zone; a tanker's station is where it is today.
- `veafSupport.lua`: a new setting `awacs_standoff` (metres, default 100000, about 55 NM), the least distance between an AWACS (`veafCampaign` already tells an AWACS from a tanker, `veafCampaign.lua` around line 3532; the module may read the group's task itself) and every enemy threat's centre, whatever its SAM reach. `veafSupport.station` keeps walking away from the threat until the point is out of every threat's reach plus `margin` **and**, for an AWACS, at least `awacs_standoff` from every threat's centre.
- Same rule when it retreats (`retreat_margin`) and when it advances (`advance_seconds`, `min_advance`): the AWACS never advances inside `awacs_standoff`.
- The tankers keep today's rule (David: handy near the front).
- Log the station's position from the bullseye when it moves (`veafSupport.fromBullseye`), so the next check can measure it rather than guess.
- Settings: add `awacs_standoff` to `dynamic.support` in the campaign's settings check (`dynamic_settings.py`) and to the shipped defaults, with its comment.
- Docs: the SUPPORT module's page (both languages) for the new setting; CHANGELOG entry.

## Done when

An AWACS held by the SUPPORT module stays at least 100 km from every enemy zone, a tanker as near the front as today; with tests.

## In-game check

On the Campagne server: the `VEAF-SUPPORT` move lines give the AWACS at 100 km or more from the nearest red zone; on the F10 map its orbit is over blue territory.

## Done (2026-11-22)

- `veafSupport.lua`: setting `awacs_standoff` (default 100000 m). `threatOver` and `station` take an optional `standoff`: a point is safe only beyond every reach plus the margin **and** `standoff` from every threat's centre. `follow` passes it for an AWACS (`veafSupport.isAwacs`: the DCS attribute `AWACS` of the group's first unit), 0 for a tanker, in danger, retreat and advance alike.
- Each move logs the orbit from the bullseye and its distance to the threat: `[AWACS Magic] retreat: orbit moved 100 km (Jisr al-Shughur), orbit now 180/81 NM from the bullseye, 100 km from [Jisr al-Shughur]`.
- Settings: `dynamic.support.awacs_standoff` in the campaign check (`dynamic_settings.py`) and the SUPPORT block of `mission.yaml` (`lua_config_generator.py`); in the shipped `campaign.yaml` and `mission.yaml` defaults, with its comment.
- Tests: `test_veafSupport.lua` (an AWACS 100 km from a MANPADS zone, a tanker where it was, the setting, no advance inside the standoff, the log line); Python, the setting accepted and passed on, 0 refused.
- Docs: `veafSupport` page and the campaign page, FR/EN.
