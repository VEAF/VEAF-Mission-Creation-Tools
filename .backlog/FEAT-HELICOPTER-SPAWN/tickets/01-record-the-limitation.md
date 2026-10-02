# 01 — Record the limitation

Status: ✅ done — recorded (now `no-airplane-spawn-from-a-marker`, helicopters being fixed by this lot); the reply to #164 is drafted for David

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

#164 is not done (see the PRD). Until it is, an agent building a mission through the MCP must learn
that no aircraft can be spawned from a marker.

## Done when

- `known-limitations.yaml` carries a `kind: tool`, `area: runtime` entry saying so, with the working routes.
- The MCP action `describe_known_limitations` returns it (`docs/agents/dcs-runtime-traps.md` renders
  only `kind: dcs` entries, so it does not change).
- A reply to #164 is drafted for David to post, correcting the 2026-08-18 comment.
