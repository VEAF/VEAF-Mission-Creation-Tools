# 01 — extract the cockpit-control index, per aircraft

Status: ✅ done.

Everything else in this lot reads this index. It turns `clickabledata.lua` — Lua source living inside
a DCS installation — into versioned data the tools can query without DCS being present.

## What goes in it

One file per aircraft, `veaf_libs/data/cockpit-controls/<type>.yaml`, keyed by element name:

```yaml
aircraft: F-16C_50
source: clickabledata.lua              # provenance, with the DCS version it came from
dcs_version: "2.9.x"
controls:
  PTR-ELEC-TMB-MPWR-510:
    argument: 510
    hint: MAIN PWR Switch, MAIN PWR/BATT/OFF
    prototype: default_3_position_tumb
    positions: [MAIN PWR, BATT, OFF]   # as named in the hint, IN HINT ORDER
    range: [-1, 1]                     # from the prototype's arg_lim
    readable: true                     # false for spring-loaded and momentary controls
```

Measured on the F-16C: 284 elements, all with an argument, 127 naming their positions.

**Done. Four aircraft indexed**, and three assumptions in this ticket turned out to be wrong:

| Aircraft | Controls | Skipped | Readable | Positions named |
|---|---|---|---|---|
| F-16C_50 | 284 | 0 | 169 | 127 |
| A-10C_2 | 470 | 4 | 185 | 8 |
| AH-64D_BLK_II | 478 | 0 | 123 | 123 |
| F-14B | 360 | 11 | 260 | 0 |

1. **`clickabledata.lua` is not one format, it is four.** The regex above matches the F-16C and
   nothing else. The AH-64D names the crew station before the hint and quotes it with apostrophes
   (0 controls until fixed); the A-10C's UFC keypad passes an empty bare hint (53 missing); Heatblur
   names its arguments — `cockpit_args.HYD_ISOLATION_Switch` — in a `draw_args.lua` table, which was
   the difference between 114 F-14 controls and 360. Each was found by indexing a real cockpit.
2. **Naming positions in the hint is an ED habit, not a convention.** Ticket 03 cannot rely on it:
   Heatblur names *none* of its positions, and the A-10C names 8 of 470. For those aircraft the
   position names have to come from somewhere else — the manual (ticket 06), or in-game measurement
   (ticket 04). This is the single biggest thing this ticket learned.
3. **The skip count has to be measured against every element declared**, not against what the
   pattern understood — the first version counted the latter and silently hid 53 A-10C controls.

The F-14B(U) shares this index: its `clickabledata.lua` is two lines of `dofile` pointing at the
F-14B's, so Heatblur's newer jet has no cockpit data of its own. Provenance carries the DCS version
read from `autoupdate.cfg` (2.9.28.26385 for these four).

**`positions` is the hint's order, and that order is not the value order** — `MAIN PWR/BATT/OFF` runs
+1 / 0 / −1 while `OFF/BACKUP` runs 0 / 1. The index records what the hint says and **does not
pretend to know the mapping**; deriving a value is ticket 03's problem, and it is expected to ask.

`readable: false` for anything whose position cannot be read at all — `springloaded_*` prototypes
(back at neutral before any poll) and `default_button` / `short_way_button` (a button has no
position). A step on one of those has to be `confirm`, and the resolver should say so rather than
emit an `argument` that never fires.

## How

A `veaf-build` command, like the other data generators (`update-dcs-data`): it reads a DCS
installation, writes the YAML, and is run by a developer who has the module — not by the build, and
not by a mission maker. The output is committed.

Parse `clickabledata.lua` with a regex over `elements["…"] = <prototype>(_("<hint>"), <device>,
<command>, <arg>, …)`, and read the prototypes' `arg_lim` / `arg_value` out of `clickable_defs.lua`.
Both are plain, regular Lua; a full parser would be over-engineering.

## Tests

`test_cockpit_controls.py`, against a fixture excerpt rather than a DCS installation: the four
prototype families parse; the argument is taken from the right position in the call; a hint with no
comma yields no `positions`; `readable` is false for `springloaded_*` and for buttons; an element the
regex cannot make sense of is reported, not silently dropped.

## Definition of done

- [x] The F-16C index generated and committed, with its provenance header — plus the A-10C II, the
      AH-64D and the F-14B, since the generator knows six aircraft and four are installed here.
- [x] The generator is a `veaf-build` subcommand (`update-dcs-data --cockpit-controls`), documented
      in [the developer guide](../../../doc/developer/dcs-data.md#cockpit-controls).
- [x] Quality gate clean, coverage floor bumped 78.5 → 79 (measured 79.22).
- [x] The indexes ship in the executable, with a packaging guard — which the previous lot's
      `checklists/` directory did not have either, so that one is now covered too.
