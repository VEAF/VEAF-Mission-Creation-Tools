# FIX-SKYNET-DYNAMICSPAWN-SCOPE — one global boolean answers two issues badly

Status: ✅ done — shipped in 6.15.8, **verified in game 2026-08-22** · archived 2026-09-28

## Verified in game, and what it took to get a valid reading

Both checks pass on `verify-mission-c`:

- **Check 6 (#151)** — a combat-zone SAM joins the red network. The zone's SA-6 was listed as an element
  of `red iads`, and it went on to **shoot the observer down**, so it was integrated *and* operational,
  not merely present in a list.
- **Check 7 (#261)** — a spawn does not wake a network that was switched off. After `Deactivate RED IADS`,
  a `-samLR, country russia` marker produced: *"DEACTIVATED from this menu, nothing has reactivated it
  since"*, `0 actual reactivation(s)`, and the new group present in the network. Exactly the intent.

`delayedActivate` still shows a non-zero count, and that is correct rather than a leak: the counter wraps
the **call**, and the guard is inside it — `if network.deactivated then return end`
(`veafSkynetIadsHelper.lua:263`), so `_activateIADS` is never reached. Zero actual reactivations is the
measurement that matters.

### Two false readings preceded the real one, both from the harness

Recorded because the pattern cost more than the lot did:

1. The mission's `dynamic_spawn` was set through the `module_settings:` hatch, which the generator had
   been silently overwriting since 2026-08-20. The mission ran with the feature **off**, so the checks
   would have measured the documented default and reported it as a result. Filed as
   [`FIX-MODULE-SETTINGS-OVERWRITTEN`](FIX-MODULE-SETTINGS-OVERWRITTEN.md).
2. The VERIFY C menu deactivated the network with `iads:deactivate()`, Skynet's raw method. The #261 fix
   keys off `network.deactivated`, a flag only `veafSkynet.deactivateNetwork` sets — so the check switched
   the network off by a route the fix cannot see, then correctly reported a spawn waking it, and printed
   **"#261 CONFIRMED" on a working product**.

Both times the code was right and the instrument was wrong. An instrument that does not measure what it
claims is worse than none, because it returns a confident verdict.

### One note for whoever re-runs this

Use **`-sa6`** rather than `-samLR` to test SAM-site integration. `-samLR` builds
`generateAirDefenseGroup-RED-4/5`, where every unit carries `random: true`: one run produced a Tor and
Skynet registered a SAM site, the next produced only a Dog Ear and Skynet registered an EWR. Both are
correct behaviour, but a non-deterministic fixture makes "did a SAM site join?" unanswerable.

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

## ⚠️ Its in-game check is blocked by a DCS defect (2026-08-20)

**Ground SAMs do not fire at all in DCS 2.9.28.26385.** Sharko reproduced it on a bare map with three
SAMs and **no scripts**, and reports the same on the BFR server. So the half of this lot's verification
that reads "the battery lights its radars and engages" cannot conclude while that lasts, and **a silent
SAM must not be read as a regression of ours**. See the warning at the top of
[DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

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

---

## Tickets, in full

## 01 — `dynamic_spawn` becomes a `mission.yaml` field

Status: ✅ done
Type: fix

Closes the half of [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) that the
verification session actually found.

### Why this is the whole of #151

The issue reads *"combat-zone SAMs are not in the IADS"*, and the DCS session of 2026-08-18 showed the
path **works**: a standard DCS SA-6 spawned by a combat zone does join the red network. Sharko's
mission simply had the flag off — and there is no way to turn it on.

`veafSkynet.DynamicSpawn` is declared at
[`veafSkynetIadsHelper.lua:72`](../../src/scripts/veaf/veafSkynetIadsHelper.lua:72) and read once, at
the end of `_initialize` (`:1057`). Nothing in the `modules:` schema reaches it. The only way today is
the migration hatch:

```yaml
module_settings:
  veafSkynet.DynamicSpawn: true
```

which exists to carry v5 missions across, not to configure a module.

### What ships

`dynamic_spawn` in the extended form of the `SKYNET` module, beside the keys that already live there:

```yaml
modules:
  SKYNET:
    enabled: true
    dynamic_spawn: true
```

- default stays **`false`** — it arms a birth-event handler on every spawn in the mission, so turning
  it on is a choice, not a default
- add it to the `registerModule` defaults table (`:1229`) and read it in the module callback, the same
  way `include_red_in_radio` is handled
- `src/defaults/mission-folder/mission.yaml` gets the key in the commented extended form, per the
  defaults-lockstep rule
- document it on the `veafSkynetIadsHelper` page in **both** languages, with what it costs and what it
  buys

### Worth documenting while here

The two integration paths are **mutually exclusive**, and nothing says so today.
[`veafSpawnCore.lua:429`](../../src/scripts/veaf/veafSpawnCore.lua:429) reads:

```lua
if veafSkynet and not veafSkynet.DynamicSpawn and options.skynet then
```

So with `dynamic_spawn` on, the spawn no longer integrates the group itself — the birth handler does.
That is why the flag looks inert when you go looking for it from the spawn side. See ticket 04, which
is the consequence of this exclusivity.

### Definition of done

- [ ] `dynamic_spawn` settable from `mission.yaml`, default `false`
- [ ] Present in `src/defaults/mission-folder/mission.yaml`
- [ ] Documented FR + EN on the `veafSkynetIadsHelper` page, cost included
- [ ] Python test asserting the key reaches the generated `veaf-config.lua`

---

## 02 — Deactivating one network must not disarm the other

Status: ✅ done
Type: fix

Half of [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261), and the half MacFlorent
explicitly parked: *"since `DynamicSpawn` is global to the module, this will set it to off globally,
but for now we will live with that"*. This ticket is the "not for now".

### The defect, visible in one line

[`veafSkynetIadsHelper.lua:1179`](../../src/scripts/veaf/veafSkynetIadsHelper.lua:1179), inside
`deactivateNetwork`:

```lua
veafSkynet.monitorDynamicSpawn(false)
iads:deactivate()
```

`monitorDynamicSpawn` removes the **one** mist event handler shared by every network
(`veafSkynet.monitorDynamicSpawnHandlerId`, `:498`). So deactivating the red network stops dynamic
integration for **blue** as well — and nothing turns it back on, because `monitorDynamicSpawn(true)`
is only ever called once, from `_initialize` (`:1057`).

Symmetrically, `veafSkynet.DynamicSpawn` is a single module-level boolean: "on for blue, off for red"
cannot be expressed at all.

### The shape of the fix

The handler stays **armed**, and the decision moves to where the network is known:

- carry the flag **per network**, in `veafSkynet.structure[networkName]` — the table already holds
  `coalitionID`, `includeInRadio`, `debugFlag`, `groups` and `iads` (`:916-922`), so it is the natural
  home
- `veafSkynet.DynamicSpawn` keeps working as the value each network is **created with**, so ticket 01's
  YAML field and the `module_settings` hatch both keep meaning what they mean
- `OnDynamicSpawn` (`:500`) already resolves the group's network by coalition (`:522`) before doing
  anything — that is the point where it asks whether *that* network wants dynamic integration, and
  returns if not
- `deactivateNetwork` clears the flag for its own network only, and stops calling
  `monitorDynamicSpawn(false)`
- keep `monitorDynamicSpawn` as the arming primitive: it is armed if **any** network wants it

### Watch for

`OnDynamicSpawn` runs on **every unit birth in the mission** once armed. Whatever the per-network
lookup costs, it must be cheap and must not raise before the early returns at `:501-519` have run —
that guard chain is what keeps the handler from doing work per unit instead of per group.

### Definition of done

- [ ] `dynamic_spawn` is per network, not module-wide
- [ ] Deactivating red leaves blue's dynamic integration armed and working
- [ ] `monitorDynamicSpawn(false)` no longer fires from `deactivateNetwork`
- [ ] Lua tests: two networks × two flag states, and "deactivate red, spawn into blue, blue integrates"

---

## 03 — A network deactivated on purpose stays down

Status: ✅ done
Type: fix

The measured half of [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261).

### Reproduction, measured in DCS on 2026-08-18

Red IADS up (EWR + static SA-6), network deactivated from a test menu, then a `-samlr, country russia`
spawned by map marker nearby:

```
VERIFY C: group added to RED network (3)
VERIFY C: delayedActivate called on RED (4)
VERIFY C: RED IADS REACTIVATED (1 since the last deactivation)
```

### The cause

`addGroupToNetwork` ends with an unconditional reactivation
([`veafSkynetIadsHelper.lua:794`](../../src/scripts/veaf/veafSkynetIadsHelper.lua:794)):

```lua
-- reactivate (rebuild coverage) the IADS
veafSkynet.delayedActivate(networkName)
```

`delayedActivate` (`:239`) schedules `_activateIADS` → `iads:activate()` (`:255-265`) with no notion of
"this network was switched off on purpose". Nothing anywhere records that intent — `deactivateNetwork`
calls `iads:deactivate()` and leaves no trace a later caller could read.

### The behaviour that ships, and why it needs no arbitration

David, asked which of *refused* / *integrated but dark* / *queued* should happen:

> on a une option pour dire si on veut que le sam soit attaché à IADS ou pas, non ?

He is right, and it settles the question. `skynet` is a **per-spawn** option, parsed at
[`veafSpawnParser.lua:45`](../../src/scripts/veaf/veafSpawnParser.lua:45), taking `true`, `false`, or a
network name. Every SAM shortcut passes `skynet true`; convoys and sanctuaries pass `skynet false`. So
the mission maker has **already said** whether this SAM belongs to the IADS, and there is no second
question to ask.

Therefore: the group **is** attached — that is what `skynet true` requests — and the attachment must
simply stop **waking the network up**. It lights up with the rest whenever something reactivates the
network deliberately. A player who wants a standalone SAM outside the network already has
`skynet false`.

### The shape of the fix

- record the deliberate deactivation on the network — `veafSkynet.structure[networkName]` again
- `delayedActivate` refuses to schedule for a network marked deactivated, and says so at debug level
  rather than silently
- a **deliberate** reactivation clears the mark. `reinitializeNetwork` (`:952`) rebuilds a network from
  scratch and so must clear it; `initializeIADS` (`:874`) activates at creation and starts unmarked
- the mark must not leak into `_activateIADS`'s own bookkeeping: it clears `network.delayedActivation`
  (`:260`), which is the *pending schedule*, a different thing from *deliberately off*

### Watch for

**Do not read an element's `isActive()` to tell whether a network is up** — it reports whether that
radar is emitting, a Skynet SAM stays dark by design until it has a contact, and
`SkynetIADS:deactivate()` never touches that state. That cost two rounds during the verification
session. Assert on `addGroupToNetwork` / `delayedActivate` / `_activateIADS` instead;
`test/veaf-tools/verify-mission-c` already carries that instrumentation.

### Definition of done

- [ ] A group spawned into a deactivated network is attached, and the network stays down
- [ ] A deliberate reactivation brings it up with everything attached meanwhile
- [ ] `reinitializeNetwork` clears the mark
- [ ] Lua test: deactivate, add a group, assert no activation was scheduled; then reactivate and assert
      the group is live

---

## 04 — `dynamic_spawn` must honour the spawn's `skynet` option

Status: ✅ done
Type: fix

Not in the original PRD. Found on 2026-08-20 by taking David's question seriously — *"on a une option
pour dire si on veut que le sam soit attaché à IADS ou pas, non ?"* — and going to check what that
option does on the `dynamic_spawn` path. Answer: nothing at all.

### The defect

`skynet` is a per-spawn option ([`veafSpawnParser.lua:45`](../../src/scripts/veaf/veafSpawnParser.lua:45)):
`true`, `false`, or a network name. It is consumed in
[`veafSpawnCore.lua:429`](../../src/scripts/veaf/veafSpawnCore.lua:429):

```lua
if veafSkynet and not veafSkynet.DynamicSpawn and options.skynet then
```

— and the comment on that line states the intent plainly:

> only add static stuff like sam groups and sam batteries, **not mobile groups and convoys** — and do
> not do that if DynamicSpawn is active in VeafSkynet

But `OnDynamicSpawn` ([`veafSkynetIadsHelper.lua:500`](../../src/scripts/veaf/veafSkynetIadsHelper.lua:500))
takes a raw DCS birth event. It has no access to `options`, never asks, and adds **any** eligible group
to its coalition's default network (`:537`). So with `dynamic_spawn` on, the global handler overrides
the per-spawn instruction, and the static-vs-mobile distinction the shortcuts encode is lost.

### Measured, not supposed

`-hv_convoy_red` passes `skynet false` explicitly
([`veafShortcuts.lua:1013`](../../src/scripts/veaf/veafShortcuts.lua:1013)). Its group, in
`veaf-units.yaml:632`, contains `Tor 9A331`, `2S6 Tunguska` and `Strela-10M3`. The first two are in
Skynet's own database (`src/scripts/community/skynet-iads-compiled.lua`), as is the
`ZSU-23-4 Shilka` of `attack_convoy_red`. `isGroupUsable` defaults to
`GroupIntegrationModes.Lenient` (`:57`), where **one** eligible unit is enough (`:574-581`).

So with `dynamic_spawn` on, an attack convoy joins the IADS against its own declaration. Same family as
#261 and #290: a global setting overriding a per-call option.

### The shape of the fix

The spawn knows the intent; the birth handler does not. The intent has to travel.

- `veafSpawnCore` records what it is about to spawn and what `skynet` said for it, in a table keyed by
  group name, before the group is created
- `OnDynamicSpawn` consults it: `skynet false` means skip; a network **name** means use that network
  rather than the coalition default (`:522` currently always takes the default, so this also fixes
  named networks being ignored on the dynamic path)
- an entry is consumed once, so the table does not grow across a long mission
- a group nobody declared — placed in the Mission Editor, spawned by a third-party script — keeps
  today's behaviour and joins the coalition default. That is the whole point of `dynamic_spawn` and
  must not regress

### Watch for

Do not fix this by re-enabling the `veafSpawnCore` branch at `:429` when `dynamic_spawn` is on: that
would integrate the group **twice** by two paths. Keep the exclusivity, move the decision.

### Definition of done

- [ ] With `dynamic_spawn` on, a group spawned with `skynet false` does **not** join any network
- [ ] With `dynamic_spawn` on, `skynet <network name>` joins that network, not the coalition default
- [ ] A group nobody declared still joins the coalition default (regression — that is the feature)
- [ ] No group is integrated twice
- [ ] Lua tests for all four cases above

---
