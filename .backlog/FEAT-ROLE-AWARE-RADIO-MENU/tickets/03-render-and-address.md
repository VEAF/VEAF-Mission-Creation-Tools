# 03 — Render the role's menu, and answer without a unit; close #128

Status: 🚫 wontfix

Cancelled with the lot on 2026-08-20 — there is nothing left to render: the lot was cancelled before a usage class existed to render. See the
[PRD](../PRD.md) for the two walls, and
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md)
for the measurements behind them.
Type: feat
Files: `src/scripts/veaf/veafRadio.lua`, the handlers taking a `unitName`, tests, mission-maker docs

Depends on [01](01-measure-what-a-game-master-is.md) and [02](02-usage-class-and-policy.md).

## Rendering

`_placeCommandOnMenu` renders anything not `USAGE_ForAll` by walking `veafRadio.humanGroups`
(`veafRadio.lua:426`), so a participant with no group gets nothing. Add the path 02's classification
calls for: a command marked as runnable unattached is **also** placed through whichever reach 01
measured to work — coalition-scoped for a game master, global for a spectator if that is the decision.

Two traps to avoid, both of which would be reported as bugs:

- **No duplicates.** A pilot must not see the same command twice because it was rendered both per
  group and coalition-wide. The existing menu already carries a coalition dimension
  (`FEAT-COMBATZONE-MENU-COALITION`) — reuse it rather than inventing a parallel one.
- **Rebuild timing.** A game master arriving after the menu was built must still get it. 01 measures
  what event, if any, his arrival raises; if none does, the menu has to exist from the start rather
  than be rebuilt on his arrival.

## Addressing

A handler invoked unattached gets no `unitName`. Today they answer with `veaf.outTextForGroup(unitName, …)`,
which cannot work. Give them one shared way to answer — an output helper that falls back to the
coalition (or global) when there is no unit — rather than letting each handler invent a fallback.
Handlers that genuinely cannot work without a caller are not in this path at all: 02 classified them
out.

## Done when

- A game master sees, and can run, the commands 02 classified as unattached — verified in game on the
  Carrier menu, the reproduction #128 was reported from
- A spectator sees exactly what 02 decided, no more
- A pilot's menu is unchanged: same commands, same order, same pagination — asserted by test, not by eye
- No command appears twice for anyone
- `veafRadio`'s doc page (both languages) documents the role dimension for mission makers
- **#128 closed**, citing the reproduction (empty Carrier menu in game master, 2026-08-18) and the fix
