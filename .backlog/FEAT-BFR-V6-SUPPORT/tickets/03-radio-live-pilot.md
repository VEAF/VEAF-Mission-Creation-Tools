# 03 — F10 menu in multiplayer: commands bound to a live pilot

Status: 🧑 waiting-human (code done; checked in game with two players in one group)

`humanUnits[x].spawned` is never reset and nothing handles a pilot leaving: when the first pilot of a group leaves, the clicks of the others stop answering.
`veaf.outTextForGroup` falls back to `trigger.action.outText`, i.e. to every player.

## Done when

- A pilot leaving his slot (`PLAYER_LEAVE_UNIT`, death, crash, ejection) is forgotten; a group's commands are bound to a pilot still present; his return rebuilds them.
- A message for a group whose group cannot be resolved is logged, never shown to everyone.
- Lua tests; checked in game with two players in one group.
