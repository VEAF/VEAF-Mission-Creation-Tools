# 01 — A test mission flown on a server, two clients compared

Status: ⬜ ready

**The mission**: a small mission on one theatre, dynamic weather on, one cyclone placed so that its front crosses an airfield within the first hour, one anticyclone elsewhere; two slots on that airfield; no other script needed. Note the DCS version.

**On the server** (Privé 2, outside the calendar's hours, never during a session; loaded with "apply extensions" off so MizEdit does not replace the weather):

1. Two clients connect, on two different machines, and take the two slots.
2. At load, then every 15 minutes for an hour, each one takes a screenshot of the same view (the airfield from the same spot, F2 or cockpit) and reads the wind and the QNH the ATIS or the kneeboard gives.
3. The server's `dcs.log` and the mission time of each capture are kept.
4. The mission is restarted once by the bot, and the first capture is taken again.

**What is answered**:

- Does the weather change during the mission (clouds, wind, pressure), and how fast?
- Do the two clients see the same weather at the same time?
- What does a restart give: the `.miz`'s starting weather again, or something else?
- Can a script read or change any of it (`world.weather` in the scripting API: fog only?), read in the API reference, not assumed.

**Sources read on 2026-11-17**, to start from (all forum posts, none official on these points):

- <https://forum.dcs.world/topic/190100-problem-with-dynamic-weather>
- <https://forum.dcs.world/topic/98296-random-dynamic-weather>
- <https://forum.dcs.world/topic/147828-real-time-weather-in-multi-player/>
- <https://forum.dcs.world/topic/174781-clouds-not-synced-in-mp/>
- <https://www.digitalcombatsimulator.com/en/news/changelog/release/2.9.6.57650/>

**Done when**: the answers are in `src/python/veaf-tools/veaf_libs/data/known-limitations.yaml` (`kind: dcs`, measured value and date, then `python -m veaf_libs.known_limitations` to regenerate `docs/agents/dcs-runtime-traps.md`), in `doc/mission-maker/PERSISTENT_CAMPAIGN.md` and `.en.md` (a short "weather" section), and David has a recommendation.
