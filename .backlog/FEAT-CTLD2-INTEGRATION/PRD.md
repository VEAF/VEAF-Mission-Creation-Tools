# FEAT-CTLD2-INTEGRATION — replace the bundled CTLD v1 with CTLD 2

**Status:** ⬜ ready

Opened 2026-08-01. Design settled in a grilling session; every decision below was taken with David
and is not open for re-litigation by the implementer.

## Why

VMCT bundles an *adapted* concatenation of the ciribob CTLD v1 monolith
(`src/scripts/community/CTLD.lua`, 428 KB). [VEAF/CTLD](https://github.com/VEAF/CTLD) is its complete
OOP rewrite — `2.0.0-rc2` at the time of writing — with its own build, its own configuration model,
its own authoring tool and 1 100+ tests. VMCT switches to it.

Two things make this more than a file swap.

**The v1 configuration channel was half broken anyway.** [veaf.lua:4673](../../src/scripts/veaf/veaf.lua)
replaces `ctld.initialize` with a VEAF wrapper carrying ~170 lines of hardcoded configuration, and
the generated block sets `ctld.<key>` *before* calling it — so every key the wrapper also sets
(`slingLoad`, `crateWaitTime`, `hoverTime`, `unitLoadLimits`, `aircraftTypeTable`, `unitActions`…)
is silently overwritten. A mission maker writing `slingLoad: false` in `mission.yaml` has never had
any effect, with no message. Moving configuration out is not a loss of a single source of truth; it
replaces a channel that half worked with one that works and is validated.

**CTLD 2 auto-initialises on load** (`CTLD_bootstrap.lua`, unless `ctld.dontInitialize = true` is set
first) and reads a **complete YAML snapshot** from `ctld.configUser`, posted by a MISSION START
trigger *before* `CTLD.lua`. There is no merge: a missing *setting* falls back to the CTLD default
(and is named in the startup report), a missing *list* is genuinely removed.

## Decisions

1. **Hard switch.** One engine bundled, no `version:` selector. A dual engine would mean writing the
   four VEAF bridges twice and carrying two configuration surfaces.
2. **Configuration leaves `mission.yaml`.** `CTLD:` keeps only its on/off flag; `settings:` is
   removed and rejected by `validate` with a message pointing at the new file. No secondary channel —
   that is what produced the silent overwrite above.
3. **`ctld-config.yaml` sits next to `mission.yaml`**, is the mission's CTLD configuration, and is
   **injected by the VMCT build only**. A mission maker edits it with `ctld-tools.exe`; they never
   use that tool's own "inject into .miz" button in a VMCT context — the build would overwrite it.
4. **The VEAF default is regenerated at build time**, not committed as a frozen snapshot: the repo
   versions a short VEAF patch (the settings currently hardcoded in `veaf.lua`), the pipeline reads
   `ctld.configDefault` out of the vendored `CTLD.lua` and applies the patch over it. A committed
   1000-line snapshot would silently deprive missions of every crate, troop and aircraft type a
   later CTLD adds — the "missing list = removed" rule.
5. **VEAF controls initialisation** (option *ii* of three): the injected trigger sets `configUser`
   **and** `dontInitialize = true`; `veaf.lua` overrides the logger, then calls `ctld.initialize()`.
   Letting it auto-start would put CTLD's whole init — including the startup report that names bad
   configuration — outside the VEAF log channel.
6. **The `logistic #001..020` / `pickzone #001..020` reserved names are dropped.** They existed
   because v1 had no discovery; CTLD 2 discovers `LGZ_` / `TRZ_` prefixed zones at boot. Verified: no
   VMCT code produces or expects those names.
7. **Log levels stay VEAF's**, by code, not by config: CTLD 2 has no log level at all
   (`ctld.utils.log` labels the text and sends everything to `env.info`). One override of
   `ctld.utils.log` replaces today's seven.
8. **New APIs, not the legacy wrappers** — `legacy_api.lua` logs a `DEPRECATED` line on every call.

## What CTLD 2 owes us

Three gaps found while auditing the bridges, filed in the CTLD repo as
`FEAT-VMCT-INTEGRATION` (+ `FIX-SHIP-ZONE-ANCHOR-PARITY`): logistic zone discovery by unit type,
ship troop-zone discovery, and a public beacon API for a caller that is not a pilot. **They land
first, in a rc3**; ticket 05 here depends on them. Tickets 01→04 and 06 do not and can proceed.

## Definition of done

- A VMCT mission with `CTLD: true` runs CTLD 2, configured by its `ctld-config.yaml`, with the
  startup report in the VEAF log.
- No `ctld.*` assignment is emitted by `lua_config_generator` any more, and
  `veaf.ctld_initialize_replacement` is gone.
- The four VEAF modules that talk to CTLD use the v2 manager APIs.
- `mission.yaml` carrying `CTLD: {settings: …}` fails `validate` with an actionable message.
- Documentation updated in FR **and** EN, `poetry run docs-check` green.

## Out of scope

- **CTLD scene plugins** ([`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins), e.g. the Metal
  FARP). Verified: the v1 copy VMCT bundles contains no Metal FARP, so no VMCT mission loses
  anything. Bundling plugins is its own lot if ever wanted.
- Foothold, which ships its own CTLD as a `custom_scripts` entry and stays incompatible with the
  VEAF one — the `foothold` conversion profile is unchanged.
