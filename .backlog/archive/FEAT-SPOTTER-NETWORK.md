# FEAT-SPOTTER-NETWORK — ground units see aircraft, and pass the word along

Status: 🧑 waiting-human — designed, built and merged 2026-09-20/21
([#972](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/972) for the design,
[#973](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/973) for the code).
**The in-game check is the one thing still owed**, and it is blocked — see *What is left* at the end.

## What it does

A ground unit that sees a hostile aircraft reports it, and the report travels from unit to unit over
the radio, one hop at a time. A SAM site that receives it does **not** light up: it holds the contact
and waits, exactly as it would for an early-warning radar, and goes live only when the aircraft
enters its own firing envelope. When the spotter loses sight of it, a cancellation travels the same
path and the defence goes quiet.

The network is therefore **a distributed EWR, not a wake-up trigger**. That framing is David's, and
it is what makes the feature fit Skynet instead of fighting it.

All of it lives in `src/scripts/veaf/veafSkynetIadsHelper.lua` — deliberately VEAF code outside
Skynet, where David placed it. The fallback for missions not using Skynet was dropped on 2026-09-20:
the feature does nothing when Skynet is off, and there is no alarm-state path.

## Settings — four keys under `modules.SKYNET`, all off or at the settled defaults

```yaml
modules:
  SKYNET:
    spotter_network: false
    spotter_radio_range_km: 20
    spotter_propagation_speed_kmh: 3600
    spotter_view: "off"     # "off" | "on" | "radio"
```

`"radio"` puts a *Show / Hide the spotter view* switch in the F10 menu, per coalition, and leaves the
view off. Everything else is a constant: detection period, the three graph periods, movement
threshold, the 10 % margin, the 3-beat tolerance, the heartbeat period and the forget delay — values
nobody can set without measuring, and each exposed key is a contract to document and keep.

Documentation: [`veafSkynetIadsHelper`](../../doc/mission-maker/scripts/veafSkynetIadsHelper.md#spotter-network),
both languages.

## Decisions not to re-argue

Each was settled with David on 2026-09-20 or 2026-09-21, with its reason.

- **The code lives in the Skynet helper**, not in a module of its own.
- **A SAM site relays and never spots.** Its detection is already the last line of defence's job,
  with a radius drawn once; a second competing radius means the larger always wins and the other is
  dead weight — the exact failure mode of the `ewr` spawn option, inert for four years. `AWACS` and
  `EWR` are excluded for the same reason, and the exclusion stops there: **aircraft do detect**
  (aeroplanes 30 km, helicopters 15 km), so a player flying for that coalition becomes a spotter.
- **Adjacency is held as sets, not lists.** Measured: re-edging 100 units costs 86 ms with lists
  against 13.7 ms with sets on the densest layout, because removing a back-edge from a list means
  scanning it.
- **Radio range 20 km**, because at 10 km the largest connected pocket covers 5.1 % of a scattered
  mission — the feature would exist and do nothing, with no way to tell why.
- **Propagation is a speed, not a period**, the hop derived as range ÷ speed, so widening the range
  cannot silently double how fast an alert crosses the map.
- **Off by default**, which is why a release note and a demonstration mission were part of the
  definition of done rather than good intentions.
- **The detection ranges are reasoned, not sourced**, and will move on a reading from play, not on
  discussion.

## What the work found that the design had wrong

`design.md` was amended twice **in place**, both times because it did not survive contact.

1. **"The ray is traced only on transitions"** cannot hold alongside its own requirement that
   masking lose a *held* contact. The affordable property is about **pairs, not beats**: a pair the
   distance test settles costs no ray at all.
2. **Its cost figures were a model's, not the code's.** The bench indexed nodes by integer; the code
   keys by unit name, and string keys are not free. Re-measured against the shipped function with a
   second bench (`test/lua/bench_spotter_shipped.lua`): **205 ms** to build the worst layout built
   (2 000 units, 234 000 edges) against 113 ms, and **19 ms** to re-edge a hundred against 13.7 ms.
   Both accepted. A parallel node array recovers ~28 % and was **not** taken: it needs the removal
   bookkeeping the set representation exists to avoid.

Also learned, and worth keeping: **`veafScheduler` ignores what a task returns** and re-arms from its
own `rep`, so periods handed back by a scheduled function are dead code that reads as if it drove the
schedule.

## What two rounds of `/code-review` found

Seven real defects, every one confirmed by probe rather than by reading. Sourcery's weekly budget was
spent, so the review replaced it rather than supplemented it.

1. **A destroyed or landed aircraft was never given up.** The detection loop only steps the pairs it
   walks, so the latch stayed *triggered* for the rest of the mission, the heartbeat kept emitting a
   network-wide wave for a jet shot down two hours earlier, and the contact was refreshed past the
   forget delay for ever. Twenty aircraft downed over four hours meant twenty permanent phantoms.
2. **The status page misattributed sightings** — flat lists printed under every debug network's
   header, so red's wake-ups read as blue's, on a page whose whole purpose is that a site can now
   light up for three different reasons.
3. **And it flooded**: one held contact wrote twelve identical `woke:` lines per page.
4. `message.dcsContact` was written, never read, and carried a comment claiming otherwise.
5. **An empty `spotter_radio_range_km:`** killed the build on a bare `TypeError` naming neither the
   file nor the key.
6. **The map view went stale**: a spotter that drove on while still watching kept its marker and its
   range circle where it started. The design had said every graph pass is a reason to redraw; that
   was the part never wired.
7. **The menu tests drove a double of `veafRadio`** written in the test file, so they pinned the
   double rather than the module.

## Traps worth carrying forward

- **`yaml.safe_load` is YAML 1.1**, so a bare `on` arrives as `True` and a bare `off` as `False`.
  Both are accepted and mapped; the documentation quotes them, because `"on"` survives a move to
  YAML 1.2 and a bare `on` would then change meaning under the mission's feet.
- **A game master has no group**, so a `USAGE_ForGroup` radio command never reaches one (#128). The
  view's toggle is posted without a usage, which resolves to `USAGE_ForAll`.
- **The map view cannot be game-master-only.** DCS offers `markToAll`, `markToCoalition` and
  `markToGroup`, nothing narrower, so every pilot of that coalition sees it — on a red network, a
  live tracker of blue aircraft. Off by default and documented as such.
- **`doc/mission-maker/LOGS.md` is not where module log output is documented.** It covers the
  `veaf-logs` viewer. The module's own page is the home. `veaf-logs` classifies Skynet lines on the
  generic `(SKYNET|skynet)` prefix, so nothing had to be added to its rules.

## What is left

**The in-game verification, and nothing else.** It is blocked, not forgotten:
`SkynetIADS:reportContact` exists in [`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS) but
**not** in the artifact vendored here, so a mission switching the feature on against the current
build gets one plain warning saying alerts travel and no site is ever woken.

`test/veaf-tools/verify-mission-c` already runs with the feature on in `"radio"` mode, and its
[check 13](../../test/veaf-tools/verify-mission-c/README.md#check-13) says exactly what to look for
in the log and on the F10 menu.

Unblocked by
[FIX-SKYNET-HELPER-AND-VENDORING ticket 03](../FIX-SKYNET-HELPER-AND-VENDORING/tickets/03-vendor-the-new-skynet-version.md),
which carries a reminder to run it.
