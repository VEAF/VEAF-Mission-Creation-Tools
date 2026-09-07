# 01 — A zone carries its own spawn-radius default

Status: ⬜ ready

Type: feat

## What it is

`VeafCombatZone:setDefaultSpawnRadius(metres)`, read by `buildGroupElement` when a group carries no
`#spawnradius=` tag of its own, in place of the module global. One line in the fluent chain a mission
maker already writes:

```lua
veafCombatZone.AddZone(
    VeafCombatZone:new()
    :setMissionEditorZoneName("CMBT_PALMYRA")
    :setFriendlyName("PALMYRA")
    :setDefaultSpawnRadius(0)   -- everything here sits in a revetment; do not move it
    :initialize()
)
```

## Precedence, and why it is three levels and not two

| Level | Written as | Wins over |
|---|---|---|
| the group | `#spawnradius=N` on a group or unit name | everything |
| the zone | `:setDefaultSpawnRadius(N)` | the module global |
| the mission | `veafCombatZone.DefaultSpawnRadiusForUnits = N` | nothing |

The bottom level already exists and is documented; the top level already exists and, since
FIX-TRIPACK-FIELD-REPORTS ticket 04, is an identity spawn when set to 0. Only the middle one is new.

Statics keep their own lane: the global pair is `DefaultSpawnRadiusForUnits` / `…ForStatics`, and a
zone-level setter that collapsed them would silently start scattering statics that default to 0
today. So either the setter takes the unit default only and statics keep the global, or it takes
both explicitly — decide it in the ticket and write the reason down, do not leave it implicit.

## The failure mode to design out

`initialize()` builds the elements and applies the default. A `setDefaultSpawnRadius` call made
**after** `initialize()` would be read by nobody, silently. This repository has paid for that shape
twice — `test_defaultSpawnRadii` asserting a constant while the default never applied, and
`spawnSmoke` confirming success with no smoke — so the setter must not be quietly ignorable. Either:

- **a** — the setter refuses (logged error) when the zone is already initialised; or
- **b** — `initialize()` is idempotent about it and re-applies the default to the elements it built.

**Recommendation: (a).** It is the honest one — the mission maker's line did nothing, and they should
be told so at load time rather than wonder in flight. (b) hides an ordering mistake and would leave
the same line meaning different things depending on where it sits.

## Definition of done

- [ ] `setDefaultSpawnRadius` on a zone changes the default its untagged groups get
- [ ] `#spawnradius=` on a group still overrides it; the module global still applies to a zone that
      sets nothing — all three levels asserted, including the pair (zone default 0, group tag absent)
      versus (zone default 50, group tag `#spawnradius=0`), which must stay distinguishable
- [ ] Statics' default is handled deliberately, with the decision written in the code's comment
- [ ] A call after `initialize()` does not fail silently
- [ ] Tests assert the **built element's** radius and the **spawned unit positions**, not the setter's
      stored value — and drive `dcs_mocks.setRandomSequence`, since the mocks' constant-0
      `math.random` makes any dispersion assertion pass both ways otherwise
- [ ] `doc/mission-maker/scripts/veafCombatZone.md` **and** `.en.md` document the three levels and
      their precedence; `poetry run docs-check` clean
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor per the ratchet policy
- [ ] Told to Tripack, with the note that the mission-wide global already exists if he ever wants
      every zone pinned at once
