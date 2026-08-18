# FIX-ESCORT-RESPAWN-TASK — a respawned escort goes home; the fix already exists next door

Status: ⬜ ready

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 9, run by David on 2026-08-18. Closes
[#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107); the same session closes
[#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) as **not reproducible**.

## The two measurements, and why they explain each other

| Path | What David saw |
|---|---|
| `veafAssets.respawn` (F10 → Assets → Respawn Arco) | the escort holds for a while, then **leaves to land after ~10 minutes** |
| `veafMove` teleport (`_move tanker, name Arco, teleport`) | the escort **stays with the tanker for the 30 minutes he watched** |

The teleport path was the one reported as broken in #101. It is not: it works, and it works because
it does something the respawn path does not.

`veafMove.teleportEscort` recovers the escort task from the group data, **reassigns the escorted
group's id into it** (`veafMove.lua:648`) and pushes the mission back to the controller through
`veafMove.replaceMission` (`:655`). The comment at `:609` says exactly why — *"it seems DCS destroys
it after the escorted group respawns"*.

`veafAssets.respawn` calls `mist.respawnGroup(name, true)` on the asset, then `mist.respawnGroup` on
each `linked` group (`veafAssets.lua:165`), and **nothing else**. The escort comes back with an
Escort task pointing at a group id that no longer exists, flies out its route, and RTBs when the
route ends — which is what a ten-minute delay looks like.

So #107's own request is the fix: *"When a functionning way is found to move the tanker by teleporting
it #101, it should be ported to the veafAssets.respawn method / mist.respawnGroup method."* That way
exists and is measured to work.

## What ships

- `veafAssets.respawn` re-establishes the escort task after respawning a linked group: same recovery
  and same group-id reassignment as `teleportEscort`, applied to the newly respawned pair.
- The logic is **shared**, not copied. Two implementations of a DCS quirk this obscure will diverge,
  and the comment explaining it must live with the code, not in one of two places.
- The naming convention (`<group> escort`) that `teleportEscort` relies on is currently implicit.
  Either the respawn path uses the same convention, or the asset's `linked` list says which group is
  an escort — decide, and document it on the ASSETS page (both languages), because a mission maker
  cannot guess it today.

## Verification

Not by unit test alone: the defect is a DCS behaviour the mocks do not model. Rerun check 9 of
`verify-mission-c` — respawn Arco, watch the escort for **longer than ten minutes**, since the
failure is a delayed RTB and a short look would have called this fixed.

## Definition of done

- [ ] A respawned escort keeps escorting, verified in game past the ten-minute mark
- [ ] One shared implementation, used by both the teleport and the respawn path
- [ ] The escort convention documented on the ASSETS page (fr + en)
- [ ] #107 closed citing the measurement; #101 closed as not reproducible, saying what was tried
      (teleport **and** move, escort observed for 30 minutes)
