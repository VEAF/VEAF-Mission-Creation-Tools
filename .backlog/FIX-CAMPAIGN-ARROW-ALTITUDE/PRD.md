# FIX-CAMPAIGN-ARROW-ALTITUDE — the assault convoy arrows slide off the ground on the F10 map

Status: 🧑 waiting-human — merged on `develop` (#1103, #1105); the line to be checked in game

## Problem

David, 2026-10-08, *Kolkhida* mission 1 in DCS, a screenshot of the F10 map: "y'a un souci sur l'affichage des flèches", then "en fait si je zoom à fond c'est correct, mais ça se décale quand on bouge la carte (même zoomée) comme si c'était sur un autre plan. T'as pas mis une altitude sur les flèches ?".

On the screenshot, the two assault-convoy axes (red Senaki → Poti, blue Kobuleti → Poti) are drawn about 25 % longer than the axes and start from one point east of Poti, away from both zones; the zone circles and labels, and DCS's own route lines of the convoys, stay in place.

`veafCampaign.sendConvoy` draws the axis with `trigger.action.arrowToAll` from `from:getCenter()` to `to:getCenter()`, both at `y = 0`; every VEAF drawing that holds still on the map takes its points from markers, on the terrain. A shape off the ground's plane moving as the map is panned is parallax.

What is not explained: the zone circles are at `y = 0` too and hold still. Only DCS can say whether ground height is the whole answer.

## What the lot does

- Both ends of the axis arrow at `land.getHeight` of their point.
- A test captures the points handed to `arrowToAll` and requires them on the terrain, source to target.
- The observation goes into `known-limitations.yaml` (`kind: dcs`), with its date and what is not confirmed.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-arrow-on-the-ground.md) | The axis arrow on the terrain — merged (#1103), did not help | ✅ |
| [02](tickets/02-a-line-not-an-arrow.md) | The axis as a line in the side's colour over the link | ✅ |

## Measured in game, 2026-10-08

With #1103 (points on the terrain) the picture did not change: David, "tes flèches c'est pas mieux… vire les. Les flèches sur les traits de liaison c'est suffisant. A moins que ça ne soient les mêmes ?". They were the same: one `arrowToAll` per convoy, shown twice — flat on the link (the coloured band he liked) and as the sliding copy. Read the same day in MOOSE (`COORDINATE:ArrowToAll`, `Core/Point.lua`), at David's request: no trick against the sliding, a plain call; but it passes the **tip first**, so our arrows pointed at their source, and the thin coloured bands on the links were more likely the convoys' routes, drawn by DCS, than a second copy of the arrow. Decided with David (option b): a `lineToAll` in the side's colour over the link, rather than no axis at all.

## To check in game

A red line from Senaki and a blue one from Kobuleti over their links to Poti, holding still as the map is panned, gone when the convoy arrives or is destroyed.
