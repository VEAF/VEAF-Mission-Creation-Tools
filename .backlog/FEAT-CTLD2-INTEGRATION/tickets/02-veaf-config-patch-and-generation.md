# 02 — the VEAF configuration patch, and generating `ctld-config.yaml` at build time

**Status:** ⬜ ready

Depends on 01.

## What changes

**A versioned VEAF patch.** A short YAML file in the repo holding *only* VEAF's deviations from the
CTLD defaults — the settings hardcoded in [veaf.lua:4536-4587](../../../src/scripts/veaf/veaf.lua)
today. Never a full snapshot (see PRD decision 4).

| Hardcoded today | Where it goes in the CTLD 2 catalogue |
|---|---|
| `addPlayerAircraftByType`, `loadCrateFromMenu`, `slingLoad`, `crateWaitTime` | same names, `mm_facing` |
| `minimumHoverHeight` 5, `maximumHoverHeight` 15, `maxDistanceFromCrate` 8, `hoverTime` 10 | same names |
| `unitLoadLimits` (10 types), `internalCargoLimits` (2) | **reprojected** into `capabilitiesByType.<type>` |
| `aircraftTypeTable` (13 types) | **the presence of a `capabilitiesByType` entry** is what makes a type a transport |
| `unitActions` (6 types) | `cratesEnabled` / `troopsEnabled` per type |
| the 20 `logistic #NNN` / `pickzone #NNN` reserved names | **dropped** (PRD decision 6) |

Once the CTLD-side ticket 01 lands, the patch also carries `logisticUnitTypes` — the carrier and FARP
types `autoInitializeAllLogistic()` scans for today. **Five types, not six:** `FARP Ammo Storage` is
the *display* name of the object whose type id is `FARP Ammo Dump Coating` (DCS sets
`swapped_names = true` on it), and `getTypeName()` returns the type id — so that entry has never
matched anything in any VEAF mission. Do not carry it over.

Reprojection is the real work here: v1 spread one aircraft's capabilities over four tables keyed by
type; v2 has one record per type. Diff the result against the CTLD default per type — several VEAF
values may already *be* the default, in which case they leave the patch.

**Generation at build.** Read `ctld.configDefault` (a long-bracket string, `CTLD.lua:2786`) out of
the vendored artifact, parse it, apply the patch, write a complete snapshot. Decide and record how:
depend on the `ctld-tools` package from the CTLD repo, or re-implement the load/patch/dump (~200
lines with `ruamel.yaml`, which VMCT already uses). Prefer the dependency if it can be consumed
without publishing to PyPI; the catalogue must not be duplicated either way.

**Where the generated file goes.** The mission folder gets a `ctld-config.yaml` when scaffolded, and
`prepare` / the build regenerate it *only if absent* — never overwrite a mission maker's edits.
A mission whose file is absent gets no `configUser` at all and CTLD runs on its own defaults.

## Open decision to record in the ticket's outcome

Whether VMCT forces `i18n_lang` in the generated file from the mission's language. Recommended yes,
**at generation only** — so it is a default the mission maker can then change, not a value the build
re-imposes on every run.

## Acceptance

- The generated snapshot is complete (parses, carries `configVersion`, every list present).
- Every VEAF value from the table above is reflected, verified key by key against the generated file.
- Regenerating after a CTLD version bump produces a snapshot carrying the new catalogue entries.
- An existing `ctld-config.yaml` is never overwritten.

## Tests

- unit: patch application over a miniature default catalogue (settings, per-type reprojection).
- unit: extraction of `ctld.configDefault` from a fixture `CTLD.lua`, including a `]]` inside the
  YAML (the long bracket level is not guaranteed to be `[[`).
- unit: absent file → generated; present file → untouched.
