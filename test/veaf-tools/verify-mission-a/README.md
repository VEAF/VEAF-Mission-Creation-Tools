# Verification mission A — ground placement (Syria, coast)

Mission A of [`CHORE-ISSUE-VERIFY-SESSION`](../../../.backlog/CHORE-ISSUE-VERIFY-SESSION/PRD.md). It
answers two issues in one load:

| Issue | Question |
|-------|----------|
| [#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232) | Is the rearm/refuel truck misplaced when a **static FARP already exists**? |
| [#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290) | Do convoys spawned by a combat zone **ever move**? |

## Where things are, and why

Forked from `smoke-test-mission`, and the ground content **stays at its anchor**: `(-32220, 405386)`,
the empty-desert spot documented as one where DCS reliably processes events. Everything placed for
this verification sits there:

| Object | Position | For |
|--------|----------|-----|
| `SmokeZone-ConvoyBlue` — 3 M 818, blue, route of two points | `(-32820, 405386)` → `(-30820, 407386)` | #290 |
| `SmokeZone-SmokeArmor` — 2 M-1 Abrams, blue, route of two points, `#alarm=2` on unit #002 | `(-32220, 405386)` → `(-30220, 407386)` | the tag check below |
| `StaticFarpAlpha` — a static FARP, blue | `(-30000, 404000)` | #232 |
| `SmokeZone` trigger zone + client slot | inherited | both |

The convoy is **prefixed with the zone name**, so the combat zone picks it up, and it carries a real
two-point route: a convoy with no route cannot fail to move and would pass the check for the wrong
reason.

**#245 is not in this mission**, and never should have been: the check needs no pilot. A script can
call the CSAR trigger over the sea, read the spawned group's position and ask `land.getSurfaceType`
what is under it — a binary verdict with no aircraft. It belongs in the smoke harness as a
`csar-avoids-water` regression check (see the lot).

The client slot is the smoke mission's **A-10C_2**, inherited. The two checks here only need *a*
slot — change the type before building if that module is not available.

## Nothing left to place

The FARP and the convoy are already in the source folder, written **durably** into `src/mission/` so
they survive a rebuild. `veaf-tools mission validate .` is clean.

Nothing is needed for #245: a CSAR is triggered from the F10 menu in flight, over water.

## Build it

```
veaf-tools mission build VerifyMissionA . --dev-mode --scripts-path <repo root>
```

`dev_mode` is not persisted in `mission.yaml` on purpose (machine-specific). Run
`veaf-tools mission validate .` first — it catches a missing coalition or an unusable slot before DCS
does.

## The protocol, in flight

Two checks, one sortie.

### 1 · #232 — rearm truck beside a static FARP

Place a marker next to the static FARP and type `-farp`.

- Compare against the screenshot on #232: the truck inside or behind the existing FARP.
- Also look at the **new** FARP's own truck: if that one is fine, the defect is about proximity, which
  is a much narrower fix.

### 2 · #290 — convoy movement

Activate the combat zone from the F10 menu and watch `SmokeZone-ConvoyBlue` for a full **60
seconds** — the Abrams of check 3 are also mobile now, so name the group you are watching.

- **Nothing moves** → confirmed. The watchdog David proposed on the issue is the likely fix.
- **It drives** → try again after a zone deactivation/reactivation cycle: the issue says *in certain
  conditions*, and a first activation may not be the failing case.

### 3 · A tag on one unit of a group — `FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`

`SmokeZone-SmokeArmor` is two M-1 Abrams, and **only the second one** carries the tag:

```
SmokeZone-SmokeArmor Unit #001
SmokeZone-SmokeArmor Unit #002 #alarm=2
```

Both carried it until 2026-08-21, which made the check pass without proving anything: the tags of every
unit of a group but the first were parsed and thrown away, so tagging both dodged the defect instead of
exposing it. A group's tags are now collected from every name that carries one, and one tag is enough.

**The group was also given a second waypoint on 2026-08-21, and that is what makes the check
readable.** With a single waypoint the group is *static*, so the nature-based default is already RED
(`FIX-COMBATZONE-ALARM-BY-NATURE`) and `#alarm=2` was indistinguishable from no tag at all — nothing
observable turned on it. With a route the default becomes AUTO, and RED has to come from the tag:

| What the tanks do | What it means |
|---|---|
| they **stay put** | the tag on unit #002 reached the group — collection works |
| they **drive off** towards `(-30220, 407386)` | the tag was ignored, the group fell back to AUTO |

Activate the zone from the F10 menu and watch for 60 seconds, as for check 2.

## Recording the outcome

Per `CHORE-ISSUE-VERIFY-SESSION`, each issue gets exactly one of three:

- **confirmed** — the reproduction written on the issue; it becomes eligible for a lot
- **not reproducible** — say what was tried, and close it
- **already fixed** — close it citing what fixed it

