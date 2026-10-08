# FIX-CAMPAIGN-ARROW-ALTITUDE — the assault convoy arrows slide off the ground on the F10 map

Status: 🧑 waiting-human — merged on `develop` (#1103); waits for the arrows holding still in DCS

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
| [01](tickets/01-arrow-on-the-ground.md) | The axis arrow on the terrain | ✅ |

## To check in game

The arrows hold still on the F10 map while it is panned, at every zoom level. If they still slide, ground height was not the cause.
