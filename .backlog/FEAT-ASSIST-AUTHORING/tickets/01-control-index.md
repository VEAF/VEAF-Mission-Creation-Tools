# 01 — extract the cockpit-control index, per aircraft

**Status:** ⬜ ready.

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

Measured on the F-16C: 284 elements, all with an argument, 131 naming their positions.

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

- The F-16C index generated and committed, with its provenance header.
- The generator is a `veaf-build` subcommand, documented in the developer guide.
- Quality gate clean, coverage floor bumped.
