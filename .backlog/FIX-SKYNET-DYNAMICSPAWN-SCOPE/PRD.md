# FIX-SKYNET-DYNAMICSPAWN-SCOPE — one global boolean answers two issues badly

Status: ⬜ ready

Origin: `CHORE-ISSUE-VERIFY-SESSION` checks 6 and 7, run in DCS on 2026-08-18. Closes
[#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) and
[#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261) — **one lot, because both are
the same design flaw seen from two ends**: `veafSkynet.DynamicSpawn` is a single global boolean.

## What the session measured

| Issue | Measured | What it means |
|---|---|---|
| #151 — "combat-zone SAMs are not in the IADS" | with `DynamicSpawn = true`, a SAM spawned by a combat zone **does** join the red network | the path works. Sharko's mission simply had the flag off — its default — and **there is no way to turn it on from `mission.yaml`** |
| #261 — "deactivating a network does not stick" | after deactivating, a `-samlr` spawn joined the network and **reactivated it** (`group added → delayedActivate → REACTIVATED`) | confirmed, and MacFlorent's analysis is right: integration ends in `veafSkynet.delayedActivate` (`veafSkynetIadsHelper.lua:794`), and the flag being global means "off for this network" cannot be expressed |

So #151 is *"the flag is invisible"* and #261 is *"the flag is not per-network"*. Fixing either one
alone leaves the other odd: exposing a global flag in YAML makes the deactivation trap easier to hit,
and scoping the flag without exposing it hides the fix.

## What ships

- **`dynamic_spawn` in `mission.yaml`**, under `modules.SKYNET`, documented on the
  `veafSkynetIadsHelper` page (both languages) with what it costs — a birth-event handler on every
  spawn. Today the only way to set it is `module_settings: { veafSkynet.DynamicSpawn: true }`, which
  is a migration hatch, not an interface.
- **Per-network state**, so deactivating a network stops *its* dynamic integration without touching
  the other coalition's. MacFlorent already framed the compromise on #261 — *"since DynamicSpawn is
  global to the module, this will set it to off globally, but for now we will live with that"*. This
  lot is the "not for now" part.
- A deactivated network **stays** deactivated until something reactivates it deliberately.
  `addGroupToNetwork` calling `delayedActivate` unconditionally is what makes that impossible.

## Open question for whoever takes it

What should happen to a group spawned **into** a deactivated network — refused, integrated but left
dark, or queued until reactivation? The issue does not say, and the answer decides how a mission
maker uses this. Ask David before choosing.

## Definition of done

- [ ] `dynamic_spawn` configurable from `mission.yaml`, documented in both languages
- [ ] Deactivating one network does not disable dynamic integration for the other
- [ ] A network deactivated stays down when a group spawns into it, per the decision above
- [ ] Lua tests covering both networks and both flag states
- [ ] Re-run checks 6 and 7 of `verify-mission-c` — the instrumentation (`group added / delayedActivate
      / reactivation` counters) is already in its `mission-script.lua`
- [ ] #151 and #261 closed citing the measurements
