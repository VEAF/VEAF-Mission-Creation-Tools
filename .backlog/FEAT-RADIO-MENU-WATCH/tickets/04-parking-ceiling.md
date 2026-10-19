# 04 — A possible 8191 ceiling on the parked pool (from DCS's binary)

Status: 🧑 waiting-human — waits for the in-game check below (David's decision a: measure first)

## What the binary shows

DCS 2.9.30 ships `bin/wRadio.dll` in the clear.
When DCS sends a menu to a client, it writes three counts for each node: its commands, its submenus, and the list that sets their display order.
Past 0x1fff = 8191, it logs `MissionCommandMenu %s, commandCount enormous %d` (or `subMenuCount` / `itemsCount`), and brings the count back to 0x2000 = 8192 when reading: the node is truncated.
The check runs on writing as well as on reading, so the sending server's `dcs.log` shows it.
The ceiling applies per node, not to the whole menu, and the "Other..." pagination does not change it.
In `wRadio.dll`, this code is only called to send a menu to a joining client and to read the three menu messages: single player never runs it, which is why the 50 000-command single-player test of 2026-10-10 could see nothing.

## What the binary does not settle

`FIX-RADIO-MENU-ID-RECYCLING` parks every freed id with `missionCommands.addCommandForGroup(999999, "parked " .. n, nil, ...)`.
A `nil` parent puts the command at the root of the group's menu, so if DCS keeps group 999999's menu, the whole pool sits in one node and hits the ceiling around 8191 parked commands.
But `wRadio.dll` only keeps a group command when its coalition is 0, 1 or 2 (neutral, red, blue); otherwise it keeps nothing and only returns the path.
The coalition of a group that does not exist is chosen in `Scripting.dll`, which is protected and was not opened.
So either the pool is kept and capped, or it is not kept at all: then there is no ceiling and no weight on joining clients, only one network message per parked command, sent before that test.

## The in-game check that settles it

1. Load a mission as a multiplayer server.
2. Park 9 000 commands for group 999999 with the same call as VMCT.
3. Have a client join.
4. Look for `commandCount enormous` in the server's `dcs.log`.

The message appears: the pool is kept and capped, and the fix below is needed.
It does not appear: there is nothing to bound, and this ticket closes with that result in the whitepapers.

## The fix, if the check shows the ceiling

Store parked commands in submenus of group 999999, a thousand each for instance, a new submenu once the current one is full.
No node then comes near 8191, and the total capacity stays far beyond any need.
Creating a submenu takes an id too, which is precisely the point of parking.
The commands stay invisible, since no player is in group 999999.

Rejected:

- **Reusing the oldest parked command**: it has to be removed first, which frees an id and reopens the hole parking closes. Parking stays append-only.
- **A periodic purge**: DCS never signals when a client closes its F10 screen, so no parked command can be proven safe to remove.

## Done when

- The in-game check above is run, and its result is in this ticket and in the whitepapers' §5.2 and §8.
- If the message appears: `veafRadio.RadioMenuBuilder:_removeEntry` stores parked commands in bounded submenus of group 999999, well under 8191 each; Lua tests on the mock pin that a new submenu opens at the boundary and that no node exceeds the cap.
- The whitepapers already describe the ceiling and the remedy as conditional (this PR); they are updated with the check's result.
