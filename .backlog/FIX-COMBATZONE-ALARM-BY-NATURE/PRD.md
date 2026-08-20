# FIX-COMBATZONE-ALARM-BY-NATURE — a zone's SAMs went silent when its convoys started moving

Status: 🧑 waiting-human

Written, unit-tested and shipped in 6.15.13. Waiting on the in-game check before publishing, since #290
was measured in game and this changes what that measurement produced — see
[DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Found on 2026-08-20, hours after shipping the change that caused it. **Not released**: 6.15.5 is closed
in the changelog but never published, so no user of the official build is affected — the window to fix
it before anyone sees it is still open.

## What we did yesterday, and what it cost

[`FIX-COMBATZONE-CONVOY-ALARM`](../archive/FIX-COMBATZONE-CONVOY-ALARM.md) (PR #762, 6.15.5) fixed
[#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290), open since April 2025: a combat
zone put **every** group it spawned on RED alert, and a DCS ground group on red alert holds position, so
convoys never drove their route. The fix introduced `veafCombatZone.DefaultAlarmState = 0` (AUTO).

Before it, `veafCombatZone` called `veaf.readyForCombat(newGroup.name)` with **no second argument**,
which falls back to `veaf.defaultAlarmState = 2` — RED. So the change is exactly: every group a zone
spawns went from RED to AUTO.

**A SAM battery on AUTO keeps its radar down.** So the same edit that let convoys move made air defences
inside combat zones go quiet. That is a straight trade of one defect for another, and the PRD of #762
**named it before making it**:

> a DCS ground group on red alert holds position: **right for a SAM battery, wrong for a convoy**

It then picked a single default anyway, with `#alarm=N` as the escape hatch. That is the part to revisit:
an escape hatch that every mission maker must apply to every existing battery is a regression, not an
option.

## What ships

The zone stops applying one default to everything and **chooses by the nature of the group**:

- a group that has somewhere to go → **AUTO**, so it goes there (this is #290's fix, preserved)
- a group that stays put → **RED**, so it fights (this is what a SAM battery, an AAA piece or a bunkered
  position wants)
- `#alarm=N` still wins over both, explicitly, as it does today

## The criterion, and the one rejected

**Chosen: does the group have a route to drive?** More than one waypoint means it is meant to move, and
"meant to move" is the entire reason AUTO was introduced. A group with nowhere to go gains nothing from
AUTO and loses its radar. This also matches #290's own framing rather than inventing a new axis.

Note for whoever implements it: a zone element only carries a route when it is a `#command` fake unit
(`setRoute` is called in that branch alone), so a native group's route has to be read from the mission
with `mist.getGroupRoute`, as the parser already does at `veafCombatZone.lua:874`.

**Rejected: the nature of the units.** Asking "does this group contain a SAM launcher or a radar" —
which `veafSkynet.isGroupUsable` already does against `iadsSamUnitsTypes` — is more precise about air
defence, but it answers the wrong question. A truck convoy with an escort SAM would come out "air
defence" and stop moving, which is the very bug #290 was about. It would also make `veafCombatZone`
depend on `veafSkynet`, which is optional. Recorded so the next reader knows it was weighed.

## Not the same defect as Tripack's

Tripack reported silent SAMs in combat zones on **6.15.2** the same day, and it looked like this bug
until he gave his version: 6.15.2 predates #762, so his groups are on RED and this cannot be his cause.
His report is still unexplained and must not be closed by this lot. What it did give us is the
discriminator — *inside a zone it fails, outside it works* — which is what led here.

## Definition of done

- [x] A SAM battery in a combat zone comes up on RED and lights its radar
- [x] A convoy in a combat zone still drives its route (regression on #290 — the whole point of #762)
- [x] `#alarm=N` still overrides, and an out-of-range tag still warns
- [x] Lua tests for both natures and for the explicit override — 12 new ones, mutation-checked (restoring a single default fails 3)
- [ ] Verified in game before publishing 6.15.x, since this is what #290's session measured
