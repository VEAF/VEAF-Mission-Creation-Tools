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

## Radio presets

**Radio preset**:
The set of radio channels injected into a human-piloted aircraft's `Radio` table
(one entry per physical radio, each a list of channel → frequency, with optional
names and modulations). The mission-maker's radio configuration lives in
`presets.yaml`. Not to be confused with a _Conversion profile_.

**Radio role**:
The functional slot a _Channel list_ plays across all aircraft, independent of
the physical radio hardware: `primary_1` (first V/UHF), `primary_2` (second
V/UHF; also the warbirds' single radio), `fm_substitute` (FM standing in for a
missing second V/UHF, on helicopters), `fm_supplement` (FM added on top of two
V/UHF, on attack aircraft), `fm_secondary` (a second supplemental FM, e.g. the
OH-58D; defaults to a copy of `fm_supplement`).

**Channel list**:
An ordered list of channels the mission-maker declares once for a given _Radio
role_ (e.g. the `primary_1`/UHF list). Author-facing content, projected onto
every aircraft that has that role. Distinct from a _Radio preset_, which is the
per-aircraft, per-physical-radio result.

**Preset plan**:
The mission-maker's full set of _Channel lists_ for a mission (by role and
coalition) — the new author-facing radio configuration, as opposed to the
per-aircraft _Radio presets_ it ultimately produces. `convert-v5` generates a
preset plan by default, falling back to a faithful per-aircraft v5 copy when the
mission cannot be factored into one.

**Channel priority**:
An optional importance rank (`priority: 1, 2, …`) a mission-maker attaches to a
channel entry **in the preset plan** (a _Channel list_ — never in
`channels_collection`). Universal meaning: the channel is highlighted on every
_Preset kneeboard_ (a `Pn` marker + emphasised cell). A _Radio layout_ may
additionally consume it as a routing directive — the only current case is the
AJS-37, whose FR22/FR24 shortcut buttons are filled from the plan's priorities
1–4, the band taken from the tagged entry's _Radio role_ (primary_1 → UHF,
primary_2 → VHF). One entry per priority value across the plan. Independent of
the channel's ordinal position in its list.

**Channel colour**:
An optional colour (`color:` — a named colour or `#RRGGBBAA`) a mission-maker
attaches to a _Channel_ to visually group related channels on the _Preset
kneeboard_. Presentation only; never affects packing.

**Radio layout**:
The VEAF-maintained description, per aircraft type, of how its physical radios
are arranged: which _Radio role_ each physical radio carries, plus that type's
quirks (channel-0 rotation, reserved head slots, hardcoded special channels,
radio fusion, slot capacity, per-channel modulation). Hand-maintained data, kept
separate from the auto-generated radio specs. A type with no layout entry falls
back to band-based defaults.

**Preset kneeboard** (FR: _planchette_):
The PNG page the presets pipeline step generates **per aircraft type** that
receives an injected _Radio preset_, dropped in that type's own kneeboard folder
(`KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png`), summarising its channels
for the pilot. "Planchette" is simply the French for kneeboard; in the presets
context it always means these injector-generated pages, not any other image a
mission may drop into its `KNEEBOARD/` folder.
_Avoid_: plate, radio page

**Mission Master (MM)**:
A trusted mission operator who drives the running mission from the F10 radio menu or
map markers — flipping flags, spawning, running maker code. VEAF exposes MM helpers
(`veafSpawn.missionMaster*`). A _user radio menu_ can be reserved to the MM by
restricting it to their DCS group (`restrict_to_group` / `radio_menu_restrict_to_group`,
a group **name** resolved to a group id at runtime).

**User radio menu**:
An F10 radio menu the mission-maker adds outside the standard VEAF tree — to
start/stop a QRA or AirWave, flip a flag, show a message, or call a maker Lua
function. Declared in YAML (`modules.RADIO.user_menus`, or the per-module
`radio_menu` shortcut on a QRA/AirWave zone) and compiled to
`veafRadio.createUserMenu`. See [ADR 0011](docs/adr/0011-radio-yaml-menus.md).
_Avoid_: custom menu (ambiguous)

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
