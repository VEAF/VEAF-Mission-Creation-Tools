# FEAT-COMBATZONE-ZONE-SPAWN-RADIUS — the dispersion default, settable from `mission.yaml`

Status: ✅ done · archived 2026-09-28

Origin: Tripack, relayed by David on 2026-09-07. He places air defences in the revetments the Syria
map draws for exactly that purpose, and a spawn that scatters a launcher by tens of metres puts it on
the berm instead of inside it. His ask: *"une option sur les CZ pour changer le default de
spawnradius. Comme ça il peut mettre 0 pour les CZ où il a beaucoup d'objets placés pile poil."*

## The first version of this PRD was wrong, and David caught it

It proposed `VeafCombatZone:setDefaultSpawnRadius(0)` as *"one line in the fluent chain the mission
maker already writes"*, and said the mission-wide default was already available as
`veafCombatZone.DefaultSpawnRadiusForUnits = 0`. David's question — *"pas de YAML pour ce param ?"* —
is the one that mattered.

**Tripack does not write that chain.** His `veaf-config.lua` opens with:

```
-- Généré par veaf-tools build depuis mission.yaml
-- Ne pas éditer manuellement.
```

The chain is emitted by `_emit_combat_zone_def`
([`lua_config_generator.py:733`](../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)), and
anything he types into the generated file is gone at the next `build`. There is **no `default_spawn_radius`
key in `mission.yaml`** at either level, and **no raw-Lua escape hatch** in the schema — checked, none.

So the honest statement of today's situation is the opposite of what the first draft said: a mission
maker on the YAML workflow **cannot set this default at all**. Tagging every group of every pinned
zone with `#spawnradius=0` is the only route open to him.

## Where it goes, and why it is two tickets

`mission.yaml` already carries both levels for this module, so no new structure is needed:

```yaml
COMBATZONE:
  combat_zone_settings:      # ← mission-wide, already holds watchdog_check_interval, radio_menu_name…
    default_spawn_radius: 0
  combat_zones:              # ← per zone, already holds friendly_name, radio_group_name…
    - zone_name: CMBT_PALMYRA
      default_spawn_radius: 0
```

The mission-wide key is nearly free: `watchdog_check_interval` → `veafCombatZone.SecondsBetweenWatchdogChecks`
is the exact same shape, three lines in the generator, and **no Lua change at all** — the global it
assigns already exists and is already documented. The per-zone key needs a Lua setter as well, since
there is nothing to assign per zone today. Hence one ticket each, the cheap and immediately useful one
first.

## Precedence

| Level | Written as | Wins over |
|---|---|---|
| the group | `#spawnradius=N` on a group or unit name | everything |
| the zone | `default_spawn_radius` under a `combat_zones` entry | the mission-wide key |
| the mission | `default_spawn_radius` under `combat_zone_settings` | the built-in default (50 / 0) |

The group level already works, and since FIX-TRIPACK-FIELD-REPORTS ticket 04 a written zero is a true
**identity spawn** — asserted to the millimetre in `test_veafCombatZone_displacement.lua`. Before that
ticket the tag alone was not enough: the anchor offset applied whatever the radius, which
`veafCombatZone.lua` admitted in its own comment (*"the delta is not only the dispersion"*).

## Rejected: a tag in the trigger zone's name

It would read naturally, the way `#spawnradius=` goes on a group. But a combat zone's name is
load-bearing: every group belonging to it must carry that name as a **prefix**, and the zone reports
the ones that do not (`reportGroupsExcludedByName`, which fired in Tripack's own log). Tagging the
zone name would either break that rule or force it to start stripping tags — a change to the naming
contract of every existing mission. And it would not help him anyway: his zone names come out of
`mission.yaml` too.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The mission-wide default comes from `mission.yaml`](FEAT-COMBATZONE-ZONE-SPAWN-RADIUS.md) | feat |
| 02 | [A zone carries its own default](FEAT-COMBATZONE-ZONE-SPAWN-RADIUS.md) | feat |

## Constraints

- **Defaults lockstep** (CLAUDE.md §9.7): both tickets change what `lua_config_generator` emits, so
  `src/defaults/mission-folder/mission.yaml` is updated in the same lot — the shipped default must
  document the new keys where a mission maker will actually meet them.
- The distinction FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT established has to survive: a default is
  applied because the tag was **not written**, never because its value happens to be 0. `0` must stay
  a legitimate written value at every level, which rules out the `if x :=` truthiness test the
  generator uses for its other keys — `if default_spawn_radius := cz_settings.get(...)` silently drops
  exactly the value Tripack wants.
- **Both languages** for the documentation, in lockstep, `poetry run docs-check` clean.
- Any test asserting dispersion must drive `dcs_mocks.setRandomSequence`: the mocks answer
  `math.random()` with a constant 0, so in the harness no spawn ever scatters and a dispersion
  assertion passes whichever way it is written. Found the hard way in FIX-TRIPACK-FIELD-REPORTS
  ticket 04.

## Delivered

Both tickets, one branch, one PR. What went in:

- `lua_config_generator` reads `default_spawn_radius` / `default_spawn_radius_statics` at both levels
  **by presence**, and the per-zone pair is emitted into the chain before `:initialize()`.
- `VeafCombatZone:setDefaultSpawnRadius` / `…ForStatics`, resolved at element-build time by
  `resolveDefaultSpawnRadius` so a global assignment and an `AddZone` call are order-independent.
  `buildGroupElement` takes the zone as an optional fourth argument, which leaves every existing
  caller — and the tests that build an element outside a zone — on the module globals.
- A call after `initialize()` is refused with a logged error rather than ignored.

**Both test suites were verified to fail**, which is the only reason to trust them:

| Mutation | What fell |
|---|---|
| generator back to `if x := cfg.get(...)` | the 4 Python tests asserting `0`, and only those |
| the zone unplugged from `buildGroupElement` | 4 of the 9 Lua tests |

One thing found and **not** turned into a change: `~= nil` versus `or` in `resolveDefaultSpawnRadius`
is not a fix in Lua, because `0` is truthy there — no test can tell the two apart. The comment that
claimed otherwise was corrected rather than left to mislead the next reader; the real version of that
trap lives on the Python side, where `0` *is* falsy, and it is what ticket 01's tests exist to catch.

---

## Tickets, in full

## 01 — The mission-wide default comes from `mission.yaml`

Status: ✅ done

Type: feat

### What it is

A `default_spawn_radius` key under `combat_zone_settings`, emitted as an assignment to the module
global that already exists:

```yaml
COMBATZONE:
  combat_zone_settings:
    default_spawn_radius: 0        # every zone of this mission places its groups exactly as drawn
```

```lua
veafCombatZone.DefaultSpawnRadiusForUnits = 0
```

No Lua change. `veafCombatZone.DefaultSpawnRadiusForUnits` is a plain module global
([`veafCombatZone.lua:36`](../../src/scripts/veaf/veafCombatZone.lua)), already read by
`buildGroupElement` when a group carries no tag, and already documented for mission makers
([`veafCombatZone.md:508`](../../doc/mission-maker/scripts/veafCombatZone.md)). The only thing
missing is the key that reaches it — which is why this ticket exists at all and why it is small.

`watchdog_check_interval` → `veafCombatZone.SecondsBetweenWatchdogChecks` is the same shape, three
lines away in the same function
([`lua_config_generator.py:681`](../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)).
Follow it.

### The one trap, and it is the whole point of the ticket

Every neighbouring key is read with a truthiness walrus:

```python
if wci := cz_settings.get("watchdog_check_interval"):
```

`0` is falsy in Python, so written that way `default_spawn_radius: 0` — **the only value Tripack
actually asked for** — would be silently dropped and the built-in 50 would apply. The key has to be
read with a presence test (`if "default_spawn_radius" in cz_settings`), the way
`event_message_combatzonecomplete` already handles its explicit `None`.

This repository has been bitten by the same class of mistake in Lua: `not 0` is false there too, and
it is what made `#spawnradius=0` indistinguishable from "unstated" for three years
(FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT). Same bug, other language.

### Statics

The global comes as a pair — `DefaultSpawnRadiusForUnits` (50) and `DefaultSpawnRadiusForStatics`
(0). A single YAML key that wrote both would silently start scattering statics that are pinned today.
So: `default_spawn_radius` sets the **unit** default, and `default_spawn_radius_statics` is offered
alongside it for completeness. Decide it explicitly in the code comment rather than leaving a reader
to wonder which one moved.

### Definition of done

- [x] `default_spawn_radius: 0` in `combat_zone_settings` reaches the generated config and applies
- [x] A Python test asserts **0 specifically**, not just some value — the truthiness trap is the
      reason for the ticket, so the test has to be able to catch it
- [x] `default_spawn_radius_statics` handled, with the pair's reason in the comment
- [x] An absent key changes nothing in the generated output (byte-identical against the current
      generator on an existing `mission.yaml`)
- [x] `src/defaults/mission-folder/mission.yaml` documents both keys in the `COMBATZONE` block
      (defaults lockstep, CLAUDE.md §9.7)
- [x] `doc/mission-maker/scripts/veafCombatZone.md` **and** `.en.md` document the key and its
      precedence; `poetry run docs-check` clean
- [x] ruff + ruff format + mypy clean over the whole Python tree, as CI runs them

---

## 02 — A zone carries its own default

Status: ✅ done

Type: feat

### What it is

A `default_spawn_radius` key on a `combat_zones` entry, so one zone can be pinned while the rest of
the mission scatters normally:

```yaml
COMBATZONE:
  combat_zones:
    - zone_name: CMBT_PALMYRA
      friendly_name: PALMYRA
      default_spawn_radius: 0     # everything here sits in a revetment; do not move it
    - zone_name: CMBT_TIYAS        # this one keeps the mission default
      friendly_name: TIYAS
```

Unlike ticket 01, this one needs Lua as well: there is no per-zone value to assign today. Three
pieces, and the middle one is the only new code in the module:

1. `VeafCombatZone:setDefaultSpawnRadius(metres)`, stored on the zone;
2. `buildGroupElement` preferring it over the module global when the group carries no
   `#spawnradius=` tag ([`veafCombatZone.lua:608`](../../src/scripts/veaf/veafCombatZone.lua));
3. `_emit_combat_zone_def` emitting `:setDefaultSpawnRadius(N)` into the chain — **before**
   `:initialize()`, which is where the emitter already puts the terminal call.

The mission maker never writes the Lua: `veaf-config.lua` carries *"Généré par veaf-tools build depuis
mission.yaml — Ne pas éditer manuellement"*, and that is the whole reason ticket 01 exists too.

### Precedence, and why it is three levels and not two

| Level | Written as | Wins over |
|---|---|---|
| the group | `#spawnradius=N` on a group or unit name | everything |
| the zone | `default_spawn_radius` on a `combat_zones` entry | the mission-wide key |
| the mission | `default_spawn_radius` under `combat_zone_settings` (ticket 01) | the built-in 50 / 0 |

The top level already exists and, since FIX-TRIPACK-FIELD-REPORTS ticket 04, is an identity spawn
when set to 0. The bottom level is ticket 01. This ticket is the middle one, and it is the one Tripack
actually asked for: *some* of his 38 zones pinned, the rest normal.

Statics keep their own lane: the global pair is `DefaultSpawnRadiusForUnits` / `…ForStatics`, and a
zone-level setter that collapsed them would silently start scattering statics that default to 0
today. So either the setter takes the unit default only and statics keep the global, or it takes
both explicitly — decide it in the ticket and write the reason down, do not leave it implicit.

### The failure mode to design out

`initialize()` builds the elements and applies the default. A `setDefaultSpawnRadius` call made
**after** `initialize()` would be read by nobody, silently. The generator puts `:initialize()` last,
so its own output is safe — but the setter is public API and a hand-written config can order it any
way it likes. This repository has paid for that shape
twice — `test_defaultSpawnRadii` asserting a constant while the default never applied, and
`spawnSmoke` confirming success with no smoke — so the setter must not be quietly ignorable. Either:

- **a** — the setter refuses (logged error) when the zone is already initialised; or
- **b** — `initialize()` is idempotent about it and re-applies the default to the elements it built.

**Recommendation: (a).** It is the honest one — the mission maker's line did nothing, and they should
be told so at load time rather than wonder in flight. (b) hides an ordering mistake and would leave
the same line meaning different things depending on where it sits.

### Definition of done

- [x] `default_spawn_radius` on a `combat_zones` entry reaches the generated chain and changes the
      default its untagged groups get
- [x] `0` survives the generator: read by presence, not by truthiness — the same trap as ticket 01
- [x] `#spawnradius=` on a group still overrides it; the module global still applies to a zone that
      sets nothing — all three levels asserted, including the pair (zone default 0, group tag absent)
      versus (zone default 50, group tag `#spawnradius=0`), which must stay distinguishable
- [x] Statics' default is handled deliberately, with the decision written in the code's comment
- [x] A call after `initialize()` does not fail silently
- [x] Tests assert the **built element's** radius and the **spawned unit positions**, not the setter's
      stored value — and drive `dcs_mocks.setRandomSequence`, since the mocks' constant-0
      `math.random` makes any dispersion assertion pass both ways otherwise
- [x] `doc/mission-maker/scripts/veafCombatZone.md` **and** `.en.md` document the three levels and
      their precedence; `poetry run docs-check` clean
- [x] `luacheck` + `stylua --check` clean; Lua coverage floor per the ratchet policy
- [x] `src/defaults/mission-folder/mission.yaml` documents the key on a `combat_zones` entry
      (defaults lockstep, CLAUDE.md §9.7)
- [x] Told to Tripack, with ticket 01's mission-wide key for the case where he wants every zone pinned

---
