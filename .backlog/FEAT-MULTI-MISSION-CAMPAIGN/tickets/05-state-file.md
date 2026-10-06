# 05 — The state file written by the mission

Status: ⬜ ready

Shared brick: the same writer is the periodic save of `FEAT-DYNAMIC-CAMPAIGN`.

The mission writes its state file **during the flight**, every `state_write_seconds` (setting), and at mission end (`S_EVENT_MISSION_END`), so a server that crashes loses at most one interval (David, 2026-10-06).

## Content

Everything the next mission depends on, as it stands at the time of writing: zone owners and captures in progress (ticket 04), garrison compositions and losses (ticket 02), stocks (ticket 06), destroyed scenery (ticket 07), plus the mission number, the campaign's format version and the mission's simulation time.
One structure with the campaign state of ticket 01, so that merging is a replacement per zone rather than a translation.

## Where

`lfs.writedir() .. "Missions/Saves/<campaign>/mission-<NN>.state"`, written with `io` to a temporary file then renamed, so that a write cut short keeps the previous one.
Without `io`/`lfs` (a sanitized install) the mission says so once in the log and to admins and runs without writing — never a crash.
On dcs.veaf.org the instance's `Saved Games` is reachable over SSH (`veaf` account): ticket 08's command takes the file from a local path, and the documentation says how to fetch it.

## Done when

Tests cover: content complete against the state, atomic write, periodic and end-of-mission writes, missing `io` handled; one in-game reading that the file is there, current, and survives a server killed mid-flight.
