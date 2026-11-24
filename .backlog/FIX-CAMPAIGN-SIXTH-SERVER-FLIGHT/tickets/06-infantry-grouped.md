# 06 — A zone's infantry grouped near its centre

Status: ✅ done
Type: feature

## Read

David, 2026-11-22: the infantry of enemy zones is very scattered and a pain to find. `veafCampaign.composeGarrison` places every group, infantry sections included, at its own random point anywhere in the zone's radius (`placeGarrisonGroup`, `veaf.findPointInZone(center, radius)`, `veafCampaign.lua` line 550); radii are 2 to 3 km.

## To do

- First, a failing test: a composed garrison places its infantry sections within `infantry_radius` of the zone's centre, on bare ground (the concrete and building checks kept); armour and air defence keep the whole radius.
- Reco: the infantry within 600 m of the centre by default, all sections around one point rather than each at its own (a position to hold, the way a pilot reads it), as a campaign setting; say the value chosen.
- Saves already on the server keep their positions: only a new draw (a capture, a redraw) places the new way. Say it in the doc.
- Docs: the campaign page where a garrison is described; CHANGELOG entry.

## Done when

A new garrison's infantry stands together near the zone's centre; with tests.

## Flight check

On the Campagne server, in a zone drawn after the deploy: the infantry found in one place, near the centre.

## Done (2026-11-23)

- `veafCampaign.composeGarrison`: one infantry position, `veafCampaign.infantryAnchor(center, infantry_radius)` — a point within `infantry_radius` of the centre, off the concrete and the buildings, up to `GARRISON_PLACEMENT_TRIES` draws — and every section placed within `INFANTRY_SPREAD` (150 m) of it, the per-section concrete and building checks kept.
  With no such point (an airfield all concrete within the radius), the sections take the whole zone, as before.
  Armour, air defence and batteries keep the whole radius.
- Value chosen: `infantry_radius: 600` (the recommendation), a top-level `dynamic` setting: `DYNAMIC_DEFAULTS`, `dynamic_settings.py`, the shipped `campaign.yaml` with its comment.
- Not changed: a helicopter capture's token garrison (one group, `composeHelicopterGarrison`), outside the ticket.
- Saves already on the server keep their positions; only a new draw (a capture, a redraw) places the new way. Said in the doc.
- Tests: `test_the_infantry_holds_one_point_near_the_centre`, `test_the_infantry_point_is_off_the_concrete`, `test_with_no_infantry_point_the_sections_take_the_whole_zone`; three placement tests updated for the extra draws.
  `test_the_upgrades_cost_about_foothold_s_prices` (economy simulator) took its median over three draws, one per seed, and the extra random draws turned two NASAMS of three into two-Avenger batteries: it now draws five offers per seed.
- Docs: *Persistent campaign*, "What the players see" and the settings table (FR/EN).
