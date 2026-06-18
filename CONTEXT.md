# VEAF Mission Creation Tools — Context

Glossary of the domain language used across the v5→v6 conversion, the YAML build
configuration, and the runtime Lua scripts. Definitions only — no implementation
detail.

## Conversion (v5 → v6)

**convert-v5**:
The command that turns a legacy v5 mission folder into a v6 one: migrates
`missionConfig.lua`, converts pipeline files, and produces `mission.yaml`.

**missionConfig migration**:
Transformation of the v5 `missionConfig.lua` into a clean v6 `mission-script.lua`
plus extracted `mission.yaml` data. Inline Lua config that maps to YAML is
extracted; the rest is annotated.
_Avoid_: config conversion, lua migration

**Pipeline file**:
A v5 source file converted at the file level (presets, waypoints, weather
versions, aircraft templates), independently of `missionConfig.lua`.

**Annotated missionConfig** (a.k.a. migration report, `convert-v5-report.md`):
The report that re-emits the v5 `missionConfig.lua` with each migrated line
commented (`-- [v6 …]`), so the mission-maker can spot what was NOT auto-migrated
and decide what to do with it.

**Iso-functional**:
Property of a converted artifact that reproduces the exact runtime behaviour of
its v5 source — e.g. a converted `presets.yaml` that yields the same radio
channels as the original v5 presets, module quirks included.

**Third-party mission**:
A `.miz` authored outside VEAF (e.g. _Foothold_ by Lekaa) that VEAF adopts onto
the v6 toolchain, as opposed to a VEAF mission migrated from v5. Re-imported from
its upstream author on a recurring basis.
_Avoid_: external mission, foreign mission

**Conversion profile**:
A declarative data file describing how to adopt a given _third-party mission_
family — script load order, native triggers to strip, config-override scaffold,
name-normalisation rules. The author-specific knowledge lives here as data, never
as code. Shipped as an overridable default.
_Avoid_: adapter, preset

## YAML configuration

**Module**:
A capability toggled and configured under the unified `modules:` block of
`mission.yaml` — covers both VEAF modules and community scripts.
_Avoid_: lua_module, plugin

**Community script**:
A third-party script (MIST, CTLD, CSAR, Skynet, STTS, Hercules…) shipped and
injected by the build. A kind of Module.
_Avoid_: external module, external script

**QRA** (Quick Reaction Alert):
The `veafQraManager` capability: interceptor groups that scramble when an enemy
enters a zone. Configured as a Module.

**Era**:
The period of a mission (`MODERN`, `COLD_WAR`, `WW2`) that constrains available
spawn content. A manual `mission.yaml` value always wins over any detection.

## Spawning

**Spawn group definition**:
A reusable, named **ground or helicopter** group definition that `veafSpawn`
instantiates in-game (via the `_spawn group` marker command). Lives in the
`veafUnits` database or in per-mission YAML. Does NOT cover aircraft spawning,
which needs a pre-existing group to clone — see _Spawnable aircraft group_.
_Avoid_: spawn template, spawnable

**Spawnable aircraft group**:
A real, hidden, late-activated aircraft group that `veafSpawn` **clones** (MiST
clone) on demand to fulfil an air spawn (e.g. the `_spawn cap` marker command).
It is NOT a template — it is an actual DCS group present in the mission. The
defining trait is its **use** (on-demand spawning), not its structure.
_Avoid_: template, model, spawnable template

**Dynamic-slot template**:
An aircraft group flagged `dynSpawnTemplate = true`, used as a **model for DCS
native Dynamic Slots** (selected in the Warehouse dialog of the mission editor).
Consumed by the DCS engine itself, never by `veafSpawn`. The defining trait is
its **use** (model for dynamic slots), not its structure.
_Avoid_: spawnable, CAP template

**On-demand spawning vs dynamic-slot model**:
The canonical split for injected aircraft groups. _Spawnable aircraft groups_
serve on-demand spawning (cloned at runtime by `veafSpawn`); _dynamic-slot
templates_ serve as static models for DCS Dynamic Slots. Same injection tool,
two distinct uses.

**veafUnits database**:
The `veafUnits.GroupsDatabase` / `veafUnits.UnitsDatabase` Lua tables of unit and
group definitions, produced by a generator script. `dcsUnits.lua` (the raw DCS
unit catalogue) is generated the same way.

## Foothold

**Foothold**:
A community-made dynamic, persistent campaign mission (originally by Lekaa) built
on Moose + a zone-commander engine + CTLD. VEAF maintains per-map variants
(Syria, Afghanistan, Caucasus, Germany, Persian Gulf, Sinai). Distinct from the
from-scratch _Dynamic campaign_ engine.
_Avoid_: Foothold mission, the campaign

**Foothold port** (a.k.a. FOOTHOLD-V6):
Bringing the existing Foothold build process onto the v6 toolchain — the mission
builds via `veaf-tools build` (mission folder + `mission.yaml`, scripts injected
as Modules, v6 static/dynamic loading). A port of the tooling, not a rework of the
Foothold gameplay or its campaign engine.

**Foothold config override**:
The set of Foothold settings a mission-maker changes at deploy time (difficulty,
start side, auto-restart…), expressed in `mission.yaml`. Applied as a partial
override layered on top of the untouched upstream Foothold config — it restates
only what changes, never the whole config.
_Avoid_: foothold settings, config patch

## Script loading

**Static loading**:
VEAF and mission scripts embedded as resources inside the `.miz` and loaded from
there at runtime.

**Dynamic loading**:
VEAF and mission scripts loaded from disk at runtime via the `VEAF_DYNAMIC_*PATH`
globals. `VeafDynamicLoader.lua` (framework layer) loads the VEAF scripts;
`veafDynamicConfig.lua` (mission layer) loads the mission scripts. Both are live,
not duplicates — see [ADR 0004](docs/adr/0004-dynamic-script-loading.md) for the
six-trigger static/dynamic flow.
