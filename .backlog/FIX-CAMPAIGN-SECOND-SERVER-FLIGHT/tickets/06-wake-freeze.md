# 06 — A zone waking up freezes the server

Status: ⬜ ready
Type: fix

## Found

"On vient juste d'avoir un gros freeze" (David, 21:02 UTC).
The only thing spawned then: **Hama woke, 42 units, its long-range SAM battery included** (logged 21:02:23, after `spawnGarrison`; the campaign beat falls about 2 s earlier).
Hama went to sleep at 21:15 ("nobody has come near it") and woke again at 21:16:21, **80 s later**; it slept again at 21:46. Bassel Al-Assad (22 units) woke at 21:16:51, Abu al-Duhur (31 units) at 20:41:51; Afrin's new garrison (24 units) spawned at 21:07.
`VeafCampaignZone:wake` spawns the whole garrison in one call; a zone wakes at `wake_radius` (60 km) and sleeps by another rule, with nothing between them.

## Measured in Tacview (2026-11-18)

Paluche's recording shows Hama's garrison (27 objects) and its long-range SAM battery (15 objects) appearing in one go at each wake, and all removed at each sleep: 84 objects created and destroyed over the evening for a zone nobody attacked.


## To do

- Spawn a waking garrison **one group per beat** (or per frame), the long-range battery last, rather than all at once; same for a garrison drawn after a capture.
- A hysteresis between waking and sleeping: a zone that just woke stays awake at least N minutes, and sleeps only beyond a radius larger than the wake radius.
- Measure the spawn time of the largest garrison on the server (time between the beat and the log line) before and after.

## Done when

The server log shows Hama's 42 units spread over several beats, a zone does not wake again within minutes of sleeping, and no freeze is reported at a wake in the next evening.
