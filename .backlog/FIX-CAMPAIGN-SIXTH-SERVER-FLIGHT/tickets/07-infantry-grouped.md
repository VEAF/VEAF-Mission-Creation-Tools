# 07 — A zone's infantry grouped near its centre

Status: ⬜ ready
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
