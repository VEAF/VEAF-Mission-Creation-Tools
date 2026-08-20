# 03 — A network deactivated on purpose stays down

Status: ✅ done
Type: fix

The measured half of [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261).

## Reproduction, measured in DCS on 2026-08-18

Red IADS up (EWR + static SA-6), network deactivated from a test menu, then a `-samlr, country russia`
spawned by map marker nearby:

```
VERIFY C: group added to RED network (3)
VERIFY C: delayedActivate called on RED (4)
VERIFY C: RED IADS REACTIVATED (1 since the last deactivation)
```

## The cause

`addGroupToNetwork` ends with an unconditional reactivation
([`veafSkynetIadsHelper.lua:794`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:794)):

```lua
-- reactivate (rebuild coverage) the IADS
veafSkynet.delayedActivate(networkName)
```

`delayedActivate` (`:239`) schedules `_activateIADS` → `iads:activate()` (`:255-265`) with no notion of
"this network was switched off on purpose". Nothing anywhere records that intent — `deactivateNetwork`
calls `iads:deactivate()` and leaves no trace a later caller could read.

## The behaviour that ships, and why it needs no arbitration

David, asked which of *refused* / *integrated but dark* / *queued* should happen:

> on a une option pour dire si on veut que le sam soit attaché à IADS ou pas, non ?

He is right, and it settles the question. `skynet` is a **per-spawn** option, parsed at
[`veafSpawnParser.lua:45`](../../../src/scripts/veaf/veafSpawnParser.lua:45), taking `true`, `false`, or a
network name. Every SAM shortcut passes `skynet true`; convoys and sanctuaries pass `skynet false`. So
the mission maker has **already said** whether this SAM belongs to the IADS, and there is no second
question to ask.

Therefore: the group **is** attached — that is what `skynet true` requests — and the attachment must
simply stop **waking the network up**. It lights up with the rest whenever something reactivates the
network deliberately. A player who wants a standalone SAM outside the network already has
`skynet false`.

## The shape of the fix

- record the deliberate deactivation on the network — `veafSkynet.structure[networkName]` again
- `delayedActivate` refuses to schedule for a network marked deactivated, and says so at debug level
  rather than silently
- a **deliberate** reactivation clears the mark. `reinitializeNetwork` (`:952`) rebuilds a network from
  scratch and so must clear it; `initializeIADS` (`:874`) activates at creation and starts unmarked
- the mark must not leak into `_activateIADS`'s own bookkeeping: it clears `network.delayedActivation`
  (`:260`), which is the *pending schedule*, a different thing from *deliberately off*

## Watch for

**Do not read an element's `isActive()` to tell whether a network is up** — it reports whether that
radar is emitting, a Skynet SAM stays dark by design until it has a contact, and
`SkynetIADS:deactivate()` never touches that state. That cost two rounds during the verification
session. Assert on `addGroupToNetwork` / `delayedActivate` / `_activateIADS` instead;
`test/veaf-tools/verify-mission-c` already carries that instrumentation.

## Definition of done

- [ ] A group spawned into a deactivated network is attached, and the network stays down
- [ ] A deliberate reactivation brings it up with everything attached meanwhile
- [ ] `reinitializeNetwork` clears the mark
- [ ] Lua test: deactivate, add a group, assert no activation was scheduled; then reactivate and assert
      the group is live
