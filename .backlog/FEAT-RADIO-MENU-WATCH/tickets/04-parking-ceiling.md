# 04 — The parked pool has an ~8191 ceiling per node (from DCS's binary)

Status: ⬜ ready

## What the binary shows

DCS's `bin/wRadio.dll` ships in the clear. Its group-menu serialiser (the function that writes a
menu node to the network stream) encodes, for each node, three child counts: direct commands,
submenus, and items. Each count is **flagged past 0x1fff = 8191** — DCS logs
`MissionCommandMenu %s, commandCount enormous %d` (or `subMenuCount` / `itemsCount`) — and **clamped
to 0x2000 = 8192 when read back**, which truncates the node and desyncs the stream.

The cap is **per node**, not global, and independent of the "Other..." display pagination.

`FIX-RADIO-MENU-ID-RECYCLING` parks every freed id with
`missionCommands.addCommandForGroup(999999, "parked " .. n, nil, ...)`, parent `nil`. Parent `nil`
means all parked commands land as **siblings at group 999999's root node**, in that node's direct-
commands collection. So the parked pool has a **hard ceiling of ~8191 commands**: past it, whenever
the group 999999 menu is serialised to a client, DCS logs `commandCount enormous` and truncates it.

### Why FEAT-RADIO-MENU-WATCH's single-player test could not see this

The 2026-10-10 measurement parked 50 000 commands in single player with no measurable cost. The cap
lives in the **network serialiser**, which runs only when a menu is transmitted to a client. Single
player transmits nothing, so the cap never fires. The 50 000-in-SP result and an 8191 MP ceiling are
not in contradiction — they exercise different code paths. This revises the PRD's "no measured cost"
for the multiplayer case.

## Still open (needs ticket 03's in-vivo measurement)

Whether the group 999999 menu is ever actually serialised and sent to clients. DCS's clear binary
shows that on client join the server sends the joining client menu data beyond its own group; whether
that walk includes synthetic member-less groups (999999) is in `Inter.dll`, which is protected and was
not opened. If it is sent, parked commands are also per-client network weight, not just a local
ceiling — which raises the urgency of the fix below from "prudence" to "necessary".

## Proposed fix — page the parked pool under the cap (option A)

Instead of posting every parked command at group 999999's root, spread them across **bounded submenus**
of that group (e.g. 1000 per submenu, a new submenu once the current one is full):

- no node ever approaches 8191 (1000 ≪ 8191), and total capacity stays effectively unbounded;
- creating a parking submenu itself consumes an id, which is exactly the point (absorbing a freed id),
  so it is neutral to the recycling mechanism;
- the commands stay invisible (no player is in group 999999).

Rejected alternatives:

- **Ring / reuse the oldest parked command**: reusing one means removing it, which frees an id and
  re-opens the very recycling hole the parking closes. Parking must stay append-only.
- **Periodic bulk purge**: DCS never signals when a client has closed its F10 screen, so a parked
  command can never be proven safe to remove.

## Done when

- `veafRadio.RadioMenuBuilder:_removeEntry` pages parked commands under bounded submenus of group
  999999, with a per-submenu cap well under 8191; Lua tests on the mock pin the paging (a new submenu
  opens at the boundary) and that no node exceeds the cap.
- The whitepaper `f10-menu-id-recycling.{fr,en}.md` records the per-node 8191 serialiser ceiling (new
  fact in §5.2 / §8) and the paging remedy, with the single-player-can't-see-it explanation.
- The PRD's "Out of scope" line on bounding the pool is updated: there is now a binary-sourced reason
  to bound it, pending ticket 03's confirmation of whether the pool reaches clients.
