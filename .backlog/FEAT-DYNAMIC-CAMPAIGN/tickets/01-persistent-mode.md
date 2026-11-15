# 01 — Persistent mode: one mission that saves and reloads itself, win, defeat, reset

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

The multi-mission campaign already has the format (`campaign.yaml`), the zones, the garrisons drawn once and recorded, the capture, the F10 map and menu and the state writer (`veafCampaign.lua`, `campaign_manager/`).
This ticket adds the second mode the decision of 2026-11-15 asks for: a single mission that runs on a server for weeks, saves itself and starts again where it stopped.

## Format

- `campaign.mode: persistent` (default `episodic`, today's behaviour).
- A `dynamic:` block of settings, all optional, with conservative defaults, read by the runtime from the data table: save cadence, dormancy, caps, enemy air, economy, tasks, intelligence (tickets 02 to 08 each add their keys).
- `sides:` reserves stay optional: a persistent campaign without them draws garrisons for free (an empty reserve would mean token garrisons).
- `campaign validate` checks the new keys; `campaign next` builds the persistent mission like mission 1 and refuses nothing else; `campaign apply` refuses a persistent campaign (there is no "between missions").

## Runtime

- The data table carries `persistent = true`.
- At start, the module reads `Saved Games\…\Missions\Saves\<campaign>\persistent.state` when it exists, is of the same campaign and format, and is not marked reset; the saved zones (owner, garrison and its losses, capture in progress), and the state of the other tickets (credits, intelligence), replace the data table's.
  A zone the save does not know starts from its declared state; a saved zone `campaign.yaml` no longer has is dropped with a log line.
- The save is the existing state writer, every `dynamic.save_seconds` (60 s) and at mission end, to that one file.
- Loaded with `loadstring` in an empty environment, so a save file cannot run code.

## Win, defeat, reset

- Victory when the enemy holds no zone, defeat when the players' side holds none: announced to everyone, the campaign freezes (no more sorties, no capture), and the save is rewritten marked `reset`, so the next load of the mission is a fresh campaign.
- An admin radio command (`veafSecurity`) resets the same way at any time.
- No mission end is forced: ending a mission needs a trigger in the `.miz`, and the server's own restart schedule already reloads the mission.

## Done when

Python: model, validation and data table tested (TDD).
Lua: load (valid, other campaign, reset, unreadable, missing `io`), overlay, victory, defeat and reset tested with the DCS mocks.
In game: capture a zone, restart the mission, the zone is still captured (verification command in ticket 09).
