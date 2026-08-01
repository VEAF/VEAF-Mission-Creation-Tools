---
status: accepted
---

# CTLD 2 is configured by a sidecar YAML, not by `mission.yaml`

Every other capability VMCT ships is configured under the unified `modules:` block of
`mission.yaml` — one file a Mission Maker edits, one source of truth. Switching the bundled CTLD from
the ciribob v1 monolith to [VEAF/CTLD](https://github.com/VEAF/CTLD) 2 breaks that uniformity for
CTLD alone, and a reader will rightly ask why.

## What forced the question

CTLD 2 reads a **complete configuration snapshot** — around 1000 lines of YAML covering settings,
crate catalogue, troop templates, zones and per-aircraft capabilities — from `ctld.configUser`, and
**does not merge**: a missing *setting* falls back to the engine default, but a missing *list* is
intentionally removed. A partial document is therefore not a partial configuration; it is a
configuration with no crates and no troops. The `modules:` model — a handful of overrides in
`mission.yaml` — cannot express it.

The uniformity it appears to sacrifice was largely notional. In v1, `lua_config_generator` emitted
`ctld.<key> = value` from `mission.yaml` and then called `ctld.initialize()`, which
`veaf.ctld_initialize_replacement` had replaced with a VEAF wrapper carrying ~170 lines of hardcoded
configuration. Every key the wrapper also set — `slingLoad`, `crateWaitTime`, `hoverTime`,
`unitLoadLimits`, `aircraftTypeTable`, `unitActions` — silently overwrote the Mission Maker's value.
`hoverPickup`, the example in the shipped `mission.yaml` comment, worked only because the wrapper
happened not to touch it.

## Decision

**A mission's CTLD configuration is a `ctld-config.yaml` file next to `mission.yaml`**, authored with
CTLD's own `ctld-tools`, and injected verbatim by the VMCT build into a MISSION START trigger placed
before `CTLD.lua`. `mission.yaml` keeps `CTLD:` as an on/off flag; `settings:` is removed and
rejected by `validate` with a message naming the replacement.

**The starting point is read from the engine, not stored here.** Scaffolding a mission with CTLD
enabled writes a `ctld-config.yaml` extracted from `ctld.configDefault` inside the vendored
`CTLD.lua`. Nothing is layered on top: comparing the eight settings VEAF used to hardcode against
the CTLD 2 defaults left **nothing to patch** — three already matched, `crateWaitTime` no longer
exists in the engine, `slingLoad` was an inconclusive experiment, and the three hover distances were
aligned on CTLD's values. Should a VEAF deviation reappear, it belongs in a short versioned patch
applied at scaffold time — never in a committed snapshot (see below).

**VEAF still owns initialisation.** The injected trigger also sets `ctld.dontInitialize = true`;
`veaf.lua` installs the log routing and then calls `ctld.initialize()`.

## Why not the alternatives

**Keep configuring in `mission.yaml` and generate the snapshot from a copy of the catalogue.** VMCT
would carry its own copy of a versioned catalogue that CTLD revises every release, and CTLD 2 already
ships version-gap detection for exactly this problem. Duplicating the catalogue means re-solving it
badly.

**Keep a copy of the catalogue in this repo and scaffold from that.** Readable in review, but frozen:
a CTLD release adding a crate section or an aircraft type would leave every new VEAF mission without
it, silently, by the "missing list means removed" rule. Reading it from the vendored engine means the
two cannot drift apart, and a CTLD upgrade needs no action here.

**Keep `settings:` working as a secondary channel.** That is precisely the silent-overwrite failure
described above, rebuilt on purpose.

**Let `ctld-tools` inject into the `.miz` itself** (it can). VMCT rebuilds the `.miz` from the mission
folder on every build, so an injection into the output is overwritten by the next build. The file in
the mission folder is the source; the build is the only writer.

## Consequences

- A Mission Maker configuring CTLD uses a second tool. Accepted: it is a graphical editor with live
  validation, against a channel that previously discarded half of what they wrote.
- `Sidecar configuration` enters the domain language ([CONTEXT.md](../../CONTEXT.md)). CTLD is the
  first; nothing obliges another script to follow, and none should unless its configuration is
  likewise a complete document owned by an upstream tool.
- The v1 reserved names `logistic #001..020` / `pickzone #001..020` disappear, superseded by CTLD 2's
  `LGZ_` / `TRZ_` zone-prefix discovery.
- VMCT stops adapting its CTLD copy: the vendored artifact becomes `verbatim`, and the ciribob
  upstream watch disappears with the fork lineage.
