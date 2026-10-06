# 03 — Runtime: F10 map and situation menu

Status: ⬜ ready

Shared brick: reused by `FEAT-DYNAMIC-CAMPAIGN`.

- F10: one filled circle per zone coloured by owner, one line per connection, the zone's name and state on its label; redrawn on change only.
- Radio: a "Campaign" menu listing the zones with owner, garrison strength (%) and capture in progress, plus the campaign's objectives and how many missions remain.
- One `veafScheduler` loop for the module, no per-zone timer; work counters (zones processed, spawns, events handled) readable by admins.

## Done when

Tests cover the drawing calls on a change and their absence without one, and the menu text in both locales; `luacheck`, `stylua` clean.
