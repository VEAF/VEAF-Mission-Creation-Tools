# FEAT-OBJECTIVE-MISSION-PROMPT — a prompt for an objective mission, played once in one session

Status: 🔄 in-progress

Asked by David on 2026-10-01. The Open Training prompt (`.prompts/new-open-training-mission.*.md`)
builds a theatre that runs for months; nothing covers a mission a group flies once: a package, one or
more objectives, a threat, a way home. The new prompt proposes a scenario first — as many as the user
wants, questions answered, a pre-briefing shown in the conversation on request — and writes nothing
until one is explicitly approved; it then builds the mission and a PPTX and/or PDF briefing following
the VEAF template (*Deep Strike Palmyra*).

Writing it found two gaps in the tools, closed in the same lot (David, 2026-10-01: "une seule PR pour
le prompt et le lot 2"):

- **No end-of-mission message.** Each zone announces its own completion, nothing announces "all
  objectives done". Combat **operations** already do ("Operation … is over"), but one could not be
  active at start from `mission.yaml` — the generator skipped `active_at_start` on operations, with no
  reason recorded (`fb99d706`) — and the completion hook given to an operation was stored and never
  called.
- **A map object cannot be an objective.** A zone only counts what it spawned; a bridge or a building
  of the map is spawned by nobody. The destroyed-scenery register (`veafMissionDb`, measured in game
  2026-08-28) already records them for the Combat Missions' *prevent destruction* objective; a zone
  had no way to use it, and the ids it needs exist only inside DCS.

Left out, on purpose: the mirror "destroy these map objects" objective for Combat Missions (David did
not take it up — the zone covers the need), and the ground-elevation table (its own lot,
[FEAT-TERRAIN-ELEVATION](../FEAT-TERRAIN-ELEVATION/PRD.md)).

To measure in DCS before closing: that `world.searchObjects` over `Object.Category.SCENERY` returns the
map objects with the ids the register records, and that a zone holding only a `scenery_targets`
completes when the object is destroyed.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [write the prompt (FR + EN) and point to it from the mission-maker doc](tickets/01-write-the-prompt.md) | ✅ |
| 02 | [`active_at_start` on a combat operation](tickets/02-operation-active-at-start.md) | ✅ |
| 03 | [call the completion hook of an operation](tickets/03-operation-completion-hook.md) | ✅ |
| 04 | [`scenery_targets`: map objects a zone must see destroyed](tickets/04-scenery-targets.md) | 🧑 |
| 05 | [`dcs scenery-objects` + `offer_scenery_lookup`: find a map object's id](tickets/05-scenery-lookup.md) | 🧑 |
