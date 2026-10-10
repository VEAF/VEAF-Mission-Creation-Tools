# 04 — Live capture by ground presence

Status: 🧑 waiting-human

Shared brick, moved here from `FEAT-DYNAMIC-CAMPAIGN` ticket 03 (David, 2026-10-06: capture happens during the flight).
The rule, Foothold's reading and the reasons are in [that ticket](../../FEAT-DYNAMIC-CAMPAIGN/tickets/03-capture.md); summarized:

- Only a **neutral** zone can be captured (its garrison destroyed, ticket 02).
- The module loop checks each neutral zone for ground presence (`world.searchObjects` over the zone): any ground unit of one side — CTLD 2 troops or vehicles, a convoy, a `_spawn` group, a Combined Arms vehicle — and a **landed** helicopter; aircraft in flight never count; a CTLD 2 crate counts through its events.
- One side alone for `capture_seconds` (default 120 s) captures; both sides present stops the clock; nobody left cancels.
- On completion the zone changes owner, the new owner's garrison is drawn (ticket 02), the capture is announced, and it is written to the state file (ticket 05).
- Campaign units that took part are consumed; units that are not the campaign's own (a player's vehicle, a `_spawn` group) are left alone.

## Airbases

- An airfield or FARP zone's airbase follows the zone's owner (`Airbase:setCoalition`).
- DCS also captures airbases on its own when enemy ground units stand on them undefended, which would make two owners fight; the campaign turns that off on its airbases (`Airbase:autoCapture(false)`) — **both API calls to verify first** in the schema and measured in game, their effect on dynamic slots and warehouses recorded in known limitations.
- CTLD logistics follow without coordination (`FEAT-CTLD-AIRBASE-LOGISTICS` reads `Airbase:getCoalition()`), after its own two minutes of presence: documented, not changed.

## Done when

Tests cover: capture only from neutral; side from the units present; contested stops the clock; everyone gone cancels; aircraft in flight ignored, landed helicopter counted; campaign units consumed, foreign units kept; crate event counted; airbase coalition and auto-capture calls made on airfields.
