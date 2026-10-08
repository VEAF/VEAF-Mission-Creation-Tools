# 04 — The campaign counts what Claude destroys

Status: ⬜ ready

`_destroy` removes units with `Unit.destroy` / `Group.destroy` / `StaticObject.destroy` (`veafSpawnObjects.lua`).
The campaign records a garrison loss on a death event (`veafCampaign.onUnitDead`), and a scripted `destroy()` is believed to raise none — **to measure**, not taken as known.

## Done when

- Measured in DCS (bridge, `world.addEventHandler` around a `Unit.destroy`): which events, if any, a scripted destroy raises; written in `known-limitations.yaml` (`kind: dcs`, dated) whatever the answer.
- If none: the destroy path tells the campaign directly (`veafCampaign.onUnitRemoved(name)` or the same path `onUnitDead` takes), so a garrison unit removed by `_destroy` — by Claude, or by a human game master — is a loss in the state file.
- What Claude spawns is not added to any garrison (D5); a test asserts a state file written after a live spawn has the same garrisons as before.
