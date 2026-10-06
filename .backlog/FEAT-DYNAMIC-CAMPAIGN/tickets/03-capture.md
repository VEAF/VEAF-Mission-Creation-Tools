# 03 — Capture: neutral zones, any ground presence, airbase ownership and slots

Status: 🚫 wontfix — moved to FEAT-MULTI-MISSION-CAMPAIGN ticket 04 (David, 2026-10-06), which builds this rule as a shared brick; kept here for its reading of Foothold

David, 2026-10-03: capture cannot be CTLD only — a convoy or troops arriving in a zone must capture too,
as in Foothold.

## How Foothold does it (read 2026-10-03, Foothold 4.7.0)

One mechanism, `ZoneCommander:startPendingCapture(side, participant)` (`zoneCommander.lua:36592`), fed
by every delivery channel:

- only a **neutral** zone can be captured;
- a **participant** — a ground group or a static (a crate) of one side, inside the zone — starts a
  capture that completes after `ZoneCaptureBuildSeconds` (**120 s** by default, `Foothold Config.lua:938`);
- more participants of the same side **join** it; the other side is refused while it runs;
- a participant that dies leaves it; when none is left the capture is cancelled, and so is it if the zone
  stops being neutral;
- on completion the zone changes owner and the participants are **consumed** (`destroyOnFinish`): the
  convoy, troops or crate disappear and the new owner's garrison appears.

The channels that call it: an AI supply convoy reaching its target zone (`:52905`), an AI ground attack
convoy reaching a neutral zone, including one bought by players (`:53020`), an AI supply helicopter or
plane landing (`:51475`, `:52900`), troops deployed by players with Foothold's CTLD (`Foothold CTLD.lua:7360`),
supply crates set down in the zone (`Foothold CTLD.lua:4818`, `zoneCommander.lua:43512`, `:69004`), a
Hercules cargo drop (`:72221`), an escorted convoy arriving (`:73297`), and admin map markers
`capture:1|2` (`:23259`). Each channel carries its own detection code.

## Here: one rule, independent of who brought the units

Instead of one detection per channel, the zone loop (ticket 02) checks each **neutral** zone — the only
ones that can be captured, so few — for ground presence (`world.searchObjects` over the zone volume):

- **Who counts**: any ground unit of a side — AI supply or attack convoy (ticket 04), troops or vehicles
  unloaded with CTLD 2, a convoy moved by `veafGroundAI`, a group spawned with `_spawn`, a player's
  Combined Arms vehicle — plus a **landed** AI supply helicopter. Aircraft in flight never count.
- **Crates**: a CTLD 2 crate set down in the zone also counts, through its `OnCrateUnloaded` /
  `OnCrateUnpacked` events (CTLD is not modified); an unpacked crate becomes vehicles, which count anyway.
- **Progress**: one side present alone for `capture_seconds` (setting, default 120 s as Foothold)
  captures the zone; **both sides present** = contested, the clock stops; nobody left = the capture is
  cancelled. Progress is shown on the zone label and announced at start.
- **On completion**, as Foothold: the participants are consumed and the new owner's garrison is drawn.
  Units that are not the campaign's own (a player's Combined Arms vehicle, a `_spawn` group) are **left
  alone** — removing a player's vehicle under him is not acceptable; to confirm with David on the first
  in-game test.
- Admins can force a capture from the radio menu (secured), replacing Foothold's map markers.

## On capture

- Owner changes, a new garrison is drawn, the zone is announced to both sides.
- Airfield or FARP zone: the airbase coalition follows (`Airbase:setCoalition` — its effect on dynamic
  slots and warehouses to measure in game and record in known limitations), so player slots open for the
  new owner and close for the old one.
- CTLD logistic zones follow the owner (coordinate with `FEAT-CTLD-AIRBASE-LOGISTICS`, which owns that
  mechanism).

## Done when

Tests cover: capture only from neutral; side taken from the units present; contested clock stops; all
participants gone cancels; aircraft in flight ignored, landed supply helicopter counted; campaign units
consumed, foreign units kept; CTLD crate event counted; airbase/slot change requested on airfields. In
game: a convoy, CTLD troops and a CTLD crate each capture a neutral zone.
