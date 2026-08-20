# FIX-SKYNET-DYNAMICSPAWN-SCOPE — one global boolean answers two issues badly

Status: 🧑 waiting-human

Written, unit-tested and shipped in 6.15.8. Waiting on checks 6 and 7 of `verify-mission-c`, which
need DCS started — the workstation this was written on has it, so it is one session away, not a
blocker. See [DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

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

## The open question, answered 2026-08-20 — and it removed itself

Asked which of *refused* / *integrated but dark* / *queued* should happen to a group spawned into a
deactivated network, David answered with a question:

> on a une option pour dire si on veut que le sam soit attaché à IADS ou pas, non ?

He was right, and it settles it without an arbitration. `skynet` is a **per-spawn** option
([`veafSpawnParser.lua:45`](../../src/scripts/veaf/veafSpawnParser.lua:45)) taking `true`, `false`, or a
network name; every SAM shortcut passes `skynet true`, convoys and sanctuaries pass `skynet false`. The
mission maker has already said whether the group belongs to the IADS, so there was no second question
to ask: the group is attached, and the attachment simply must not wake the network up.

## A fourth defect, found by checking that answer

Taking the question seriously and going to look at what the option *does* on the dynamic path turned up
a defect the PRD did not know about: it does nothing at all. `OnDynamicSpawn` takes a raw DCS birth
event, never consults the option, and integrates every eligible group. So with `dynamic_spawn` on,
`-hv_convoy_red` — `skynet false`, and carrying a Tor, a Tunguska and a Strela, all in Skynet's
database — joined the IADS against its own declaration. Same family as #261 and #290: a global setting
overriding a per-call option. Filed as ticket 04 and fixed with the rest.

## Two things that had to come with it

- **`veafSkynet.activateNetworkOfCoalition`**, because the API had `deactivateNetwork` with no
  symmetric half. Once a deactivated network stays down, "stays down" would have meant "forever".
- **The exclusivity of the two integration paths now asks the network**, not the module-level flag,
  which is only the value a network is *created* with. Otherwise a network whose integration was
  switched off mid-mission would have had `skynet true` silently dropped by both paths.

## Definition of done

- [x] `dynamic_spawn` configurable from `mission.yaml`, documented in both languages
- [x] Deactivating one network does not disable dynamic integration for the other
- [x] A network deactivated stays down when a group spawns into it — the group is attached, the
      network does not wake up, and a deliberate reactivation brings it up with everything attached
- [x] The dynamic path honours the per-spawn `skynet` option, network names included (ticket 04)
- [x] Lua tests covering both networks and both flag states — 48 new ones, and the three guards were
      **mutation-checked**: each was neutralised in turn to prove a test fails. That pass caught two
      of my own tests passing for the wrong reason (`_makeGroupWithUnits` hardcodes BLUE, so a RED
      network made them pass on a coalition mismatch rather than on the guard under test)
- [ ] Re-run checks 6 and 7 of `verify-mission-c` — the instrumentation (`group added / delayedActivate
      / reactivation` counters) is already in its `mission-script.lua`
- [ ] #151 and #261 closed citing the measurements
