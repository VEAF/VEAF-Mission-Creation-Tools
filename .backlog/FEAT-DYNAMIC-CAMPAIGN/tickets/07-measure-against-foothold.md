# 07 — Measure it against Foothold

Status: ⬜ ready

Moved here from the head of the lot (David, 2026-10-03: a profiling evening on a modified Foothold is not
for now). Measured at the end it answers the question that matters — did we gain — with both engines
under the same conditions, instead of a lone Foothold baseline.

No modified mission is needed:

- **FPS**: DCSServerBot already records a per-minute FPS series per server (`perfmon`, `monitoring` /
  `serverstats`). Compare a Foothold evening and a campaign evening at similar player counts — read
  through the bot's Discord server-load command, or by David from the database.
- **Lua share**: DCSServerBot's `profiler` plugin, `sample` mode (the light one), for a bounded period on
  each mission (`/profiler start profiler:sample` … `/profiler stop`). It must first be added to
  `opt_plugins` on the production bot — David's call, it is production configuration.

## Then tune

If the campaign evening shows the server struggling, lower the caps (materialized groups, sorties,
convoys) and the dormancy radius — the settings ticket 02 and 04 created — until it holds; record the
values that held and on which server.

## Done when

The PRD carries both measurements with their dates and conditions, the verdict on David's starting
hypothesis (Moose) as far as the profiles allow, and the caps' defaults set from what the server held. Does **not** block the merge of tickets 01–06.
