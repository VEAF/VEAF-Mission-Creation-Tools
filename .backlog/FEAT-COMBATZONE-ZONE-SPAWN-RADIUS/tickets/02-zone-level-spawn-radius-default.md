# 02 — A zone carries its own default

Status: ✅ done

Type: feat

## What it is

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
   `#spawnradius=` tag ([`veafCombatZone.lua:608`](../../../src/scripts/veaf/veafCombatZone.lua));
3. `_emit_combat_zone_def` emitting `:setDefaultSpawnRadius(N)` into the chain — **before**
   `:initialize()`, which is where the emitter already puts the terminal call.

The mission maker never writes the Lua: `veaf-config.lua` carries *"Généré par veaf-tools build depuis
mission.yaml — Ne pas éditer manuellement"*, and that is the whole reason ticket 01 exists too.

## Precedence, and why it is three levels and not two

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

## The failure mode to design out

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

## Definition of done

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
