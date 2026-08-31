# Combat zones

## What it is {#what-it-is}

An objective prepared in the DCS editor and **activated on demand** from the F10 radio menu. At
start-up the zone is emptied: its groups are destroyed. On activation they are recreated, and the
zone declares itself complete once the enemy is gone.

A zone is declared in three pieces, two in the DCS editor and one in `mission.yaml`.

## The smallest example that works {#minimal-example}

**1. In the DCS editor** — a trigger zone named `CZ-Alpha`.

**2. In the DCS editor** — a group placed inside it, named `CZ-Alpha-ARMOR`.

**3. In `mission.yaml`**:

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: true
```

`zone_name` is the only required key; it is the trigger zone's name, character for character.
`friendly_name` is what the player reads in the menu; without it, they read `zone_name`.

In game: **F10 "Other" → COMBAT ZONES → Alpha Zone → Activate zone**. The message
"VeafCombatZone Alpha Zone has been activated." appears, the contents show up a second later, and
the zone report follows.

## The gotcha {#gotcha}

**The group's name must start with the zone's name.** Putting a group inside the trigger zone is not
enough: the zone only captures groups whose name **starts with** its own (case is ignored). A group
called `ARMOR-1` sitting neatly inside `CZ-Alpha` is simply ignored; it must be `CZ-Alpha-ARMOR-1`.

The dangerous corollary runs the other way: an unrelated group named `CZ-Alpha-something` and placed
inside the zone will be destroyed at mission start.

Nothing shows in game either way, but **the DCS log names what the zone left behind** — one line per
zone at start-up, listing the groups it found inside and turned down. A zone that "spawns nothing" is
worth one look at the log before anything else.

Second gotcha: `training: true` is not cosmetic. Without it the menu entry reads `+Activate zone`
and demands an authenticated radio — handy on a server, baffling while you are learning.

## `training: true` or not {#training}

| | menu entry | who can activate |
|---|---|---|
| `training: true` | `Activate zone` | anyone |
| absent or `false` | `+Activate zone` | an authenticated radio only ([security](../scripts/veafSecurity.en.md)) |

## Spawning VEAF units instead of hand-placed ones {#command-units}

Rather than placing units one by one, drop a dummy unit whose **name** carries a VEAF command. It is
destroyed at start-up, and the command runs on activation:

```
CZ-Alpha-SAM #command="-samLR"
```

The alias (`-samLR`, `-samSR`, `-armor`…) comes from the [alias catalogue](../../ALIASES.en.md) —
there is no `-lrsam`, it is `-samLR`.

## Dialling in the randomness {#randomness}

Markers inside names tune the spawn behaviour:

| Marker | Effect | Default |
|---|---|---|
| `#spawnchance=50` | this group has a 50 % chance of spawning | 100 |
| `#spawncount=2` | exactly 2 groups among the zone's | 1 |
| `#spawnradius=200` | random dispersion, in metres | 50 m (group), 0 m (static) |
| `#spawndelay=60` | delayed spawn, in seconds | no delay |

!!! warning "This changes existing missions"
    `#spawnchance` **really does deny** a spawn: a group at 50 % spawns half the time, and a group
    at 0 % never spawns. The guarantee of a number stays with `#spawncount`: two groups asked for
    out of four give exactly two, drawn at random. Missions that used `#spawnchance` will therefore
    see **fewer** spawns than before.

## Going further {#more}

- [veafCombatZone — the prefix rule in detail](../scripts/veafCombatZone.en.md#zone-membership)
- [veafCombatZone — full configuration](../scripts/veafCombatZone.en.md#configuration-missionyaml)
- [veafCombatZone — every name marker](../scripts/veafCombatZone.en.md#spawn-radius)
- [veafCombatZone — where the markers are read](../scripts/veafCombatZone.en.md#tag-sources)
- [veafCombatZone — who is offered the F10 menu](../scripts/veafCombatZone.en.md#f10-menu-audience)
- [Marker aliases](../../ALIASES.en.md)
