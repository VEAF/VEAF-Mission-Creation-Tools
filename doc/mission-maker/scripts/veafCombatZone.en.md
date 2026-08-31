# veafCombatZone — Activatable Combat Zones


**Module ID:** `COMBATZONE` | **File:** `veafCombatZone.lua`

---

## Purpose

Defines named combat zones in the mission editor that players can activate and deactivate via the F10 radio menu. Each zone tracks enemy unit state, fires objective-completion events, supports scoring, and can contain multiple unit groups with spawning rules.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafSpawn` — unit spawning backend
- `veafMarkers` — optional marker commands

---

## Enable

```lua
veafCombatZone.initialize()
```

Individual zones are created and initialised separately (see below).

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  COMBATZONE:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    combat_zone_settings: # optional global overrides
      event_message_combatzonecomplete: "Zone objective complete!"  # null = suppress
      watchdog_check_interval: 30          # seconds between zone watchdog polls (default: 60)
      radio_menu_name: "Combat Zones"      # F10 menu label
      combat_zone_menu_name: "Combat Zone Operations"
      operation_menu_name: "Operations"
    combat_zones:         # zone and operation definitions
      - type: zone                          # zone | operation
        zone_name: "CZ-Alpha"              # DCS trigger zone name
        friendly_name: "Alpha Zone"        # label in radio menu
        radio_group_name: "North"          # gather same-named zones under one shared submenu
        radio_menu_prefix: "BLUE"          # prefix shown before the zone label
        briefing: "Destroy the armoured column."  # shown in mission info
        training: false                     # true = no security, verbose status
        active_at_start: true               # automatically activate the zone at mission start
        chained_zones:                      # zones to trigger when this one completes
          - "CZ-Bravo"
        chained_delay: 60                   # seconds before chaining fires
      - type: operation
        zone_name: "Op-Thunder"
        friendly_name: "Operation Thunder"
        tasking_orders:
          - zone_name: "CZ-Alpha"           # first task (no dependencies)
          - zone_name: "CZ-Bravo"
            dependencies:                   # CZ-Bravo unlocks after CZ-Alpha
              - "CZ-Alpha"
```

### `combat_zone_settings` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `event_message_combatzonecomplete` | string \| null | *(module default)* | Message broadcast when a zone completes. `null` suppresses it. |
| `watchdog_check_interval` | integer | `60` | Seconds between watchdog polls |
| `radio_menu_name` | string | `"COMBAT ZONES"` | F10 top-level menu label |
| `combat_zone_menu_name` | string | *(default)* | Sub-menu label for zone operations |
| `operation_menu_name` | string | *(default)* | Sub-menu label for operations |

### `combat_zones[]` fields — type `zone`

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `type` | string | `zone` | No | `zone` or `operation` |
| `zone_name` | string | — | Yes | DCS trigger zone name |
| `friendly_name` | string | — | No | Label shown in the F10 menu |
| `radio_group_name` | string | — | No | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
| `radio_menu_prefix` | string | — | No | Prefix shown before the zone label in the menu |
| `briefing` | string | — | No | Briefing text shown to players |
| `training` | boolean | `false` | No | Training mode: no security, verbose status |
| `completable` | boolean | `true` | No | `false`: the zone never completes (nor deactivates) on its own |
| `show_units_list` | boolean | `true` | No | `false`: the F10 report does not list the remaining units |
| `show_zone_position_info` | boolean | `true` | No | `false`: the F10 report shows neither the zone's coordinates nor its weather |
| `smoke_and_flare` | boolean | `true` | No | `false`: the zone offers neither smoke nor flare to mark itself |
| `radio_menu_disabled` | boolean | `false` | No | `true`: the zone does not appear in the F10 menu at all |
| `rename_units_sequentially` | boolean | `true` | No | `false`: units keep their original names when spawned instead of being renamed in sequence. See [below](#rename-units) |
| `enemy_coalition` | `RED` \| `BLUE` | `RED` | No | The **hostile** coalition: its units are the ones that must be destroyed for the zone to complete, and the ones the F10 report calls "enemies". Use `BLUE` for a zone played from the **red side** (see below) |
| `radio_menu_coalition` | `RED` \| `BLUE` \| `ALL` | *(the side playing the zone)* | No | Which coalition is offered the zone's F10 menu. Defaults to the opposite of `enemy_coalition`. `ALL` shows it to both sides (see below) |
| `active_at_start` | boolean | `false` | No | Automatically activate the zone at mission start (`veafCombatZone.ActivateZone` after `initialize()`) |
| `chained_zones` | string[] | `[]` | No | Zone names to trigger on completion |
| `chained_delay` | integer | `0` | No | Seconds before chained zones fire |

### `rename_units_sequentially` — keeping the original unit names {#rename-units}

When a group spawns, a combat zone renames its units in sequence. That helps on a finished map — the names become readable and consistent — and **gets in the way while debugging** a `.miz`: the name you gave the unit in the Mission Editor is gone, and you can no longer find it in the logs.

```yaml
combat_zones:
  - zone_name: CZ-Alpha
    rename_units_sequentially: false   # units keep their Mission Editor names
```

The setting is **per zone**, not a global debug switch: that is what the
[original request](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/289) asked for, and a global one would be one more thing to remember to put back before shipping.

The default stays `true`, so no existing mission changes.

### `combat_zones[]` fields — type `operation`

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `type` | string | — | Yes | Must be `operation` |
| `zone_name` | string | — | Yes | DCS trigger zone name |
| `friendly_name` | string | — | No | Label in the radio menu |
| `briefing` | string | — | No | Briefing text |
| `tasking_orders` | object[] | `[]` | No | Ordered task list |
| `tasking_orders[].zone_name` | string | — | Yes | Combat zone name for this task |
| `tasking_orders[].dependencies` | string[] | `[]` | No | Zone names that must complete first |

### Minimal example

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Alpha"
        friendly_name: "Alpha"
```

### A zone played from the red side {#red-side-zone}

By default a combat zone assumes the players are **blue** and the units to destroy are **red**.
Two behaviours followed from that: the zone completed once no red unit was left, and the F10
report labelled the blue tally "friends" and the red one "enemies".

`enemy_coalition: BLUE` flips both: the zone completes once its **blue** units are destroyed, and
the report calls the blue units "enemies" and the red ones "friends".

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Kobuleti"
        friendly_name: "Kobuleti"
        enemy_coalition: BLUE   # players are red, blue are the enemies
```

Unit counting itself is unchanged — only the side the completion condition looks at. A zone that
says nothing behaves exactly as before.

> A zone holding no red unit previously needed `completable: false`, which did not make it a
> red-side zone: it merely switched auto-completion off, and the report still called the blue
> enemies "friends". `enemy_coalition` replaces that workaround.

In Lua the equivalent is `VeafCombatZone:setEnemyCoalition(coalition.side.BLUE)`; the setter also
accepts the `"blue"` / `"red"` string form.

### Who is offered the F10 menu? {#f10-menu-audience}

A zone's F10 menu is not read-only: it is how the zone gets **activated**, its status requested,
its smoke popped. So it is offered to the **side playing the zone** — the opposite of
`enemy_coalition`:

| `enemy_coalition` | F10 menu visible to |
|-------------------|---------------------|
| `RED` (default) | blue |
| `BLUE` | red |

Nothing to write to get that. To override it, use `radio_menu_coalition`:

```yaml
      - type: zone
        zone_name: "CZ-Alpha"
        radio_menu_coalition: ALL   # both sides see the zone and can activate it
```

`ALL` is what you want for an umpire or Mission Master sitting in a red slot who must be able to
trigger a blue zone. A side can also be named explicitly (`RED` / `BLUE`) when it is not the one
playing the zone.

> **Behaviour change (6.11.8)**: before this version every zone was offered to both sides. A
> mission whose player slots are all blue sees no difference; a mission with red slots that must
> keep access to the blue zones needs `radio_menu_coalition: ALL` on those zones.

The parent menu (`COMBAT ZONES`, and the `radio_group_name` submenu) stays visible to everyone: a
radio group may hold zones of both sides. So each side sees the `COMBAT ZONES` entry without the
other side's zones under it.

In Lua: `VeafCombatZone:setRadioMenuCoalition(coalition.side.RED)` or `"all"`.

---

## How it works

Place all the units that should appear in the zone directly in the DCS Mission Editor, inside the trigger zone, **and name their groups so they start with the zone's name** — this is [the prefix rule](#zone-membership), the one rule that decides what the zone contains. When the mission starts VEAF removes them all — the zone is empty. When a player activates the zone via the F10 menu, all units are respawned at randomised positions within the zone radius. When every enemy unit is destroyed, the zone is marked as completed (optional callback fires, optional chained zones activate).

This approach gives you full visual design in the editor while keeping the zone inactive at mission start.

### Setting up in the DCS Mission Editor

1. **Create a trigger zone** — define the combat area. Name it, e.g. `CZ-Alpha`.
2. **Place unit groups** inside the zone, **prefixing their names with the zone's name** — `CZ-Alpha-ARMOR`, `CZ-Alpha-AAA`. Set them to any coalition — VEAF will handle their lifecycle.
3. **Use unit or group name tags** (see below) to customise spawn behaviour per group.
4. **Register the zone** in `mission-script.lua`:

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("CZ-Alpha")        -- DCS trigger zone name
  :setFriendlyName("Alpha")                    -- radio menu label
  :setBriefing("Strike Alpha — Armoured column")
  :initialize()
```

`veafCombatZone.initialize()` must be called at the module level first.

---

### The prefix rule — what the zone picks up {#zone-membership}

**A group belongs to the zone if, and only if, its name starts with the trigger zone's name.** Case
is ignored, and nothing else is looked at. Standing inside the circle is necessary, but it is not
enough.

The name that counts is the **DCS trigger zone's** — `zone_name` in YAML,
`:setMissionEditorZoneName(...)` in Lua. Not the `friendly_name` shown in the radio menu, which is
only a label.

For a zone named `CZ-Alpha`:

| Group name in the editor | Picked up? | Why |
|---|---|---|
| `CZ-Alpha-ARMOR` | yes | starts with `CZ-Alpha` |
| `CZ-Alpha-AAA` | yes | starts with `CZ-Alpha` |
| `cz-alpha-manpads` | yes | case is ignored |
| `CZ-AlphaSAM` | yes | it is a prefix, not a segment: the dash is not required |
| `ARMOR-1` | **no** | does not start with `CZ-Alpha`, even sitting dead centre in the circle |
| `Alpha-ARMOR` | **no** | `CZ-` is missing |

A static object is its own group: the rule then applies to **its** name.

!!! danger "A misnamed group fails silently"
    Nothing reports it, neither in game nor in the log. The zone activates normally and announces
    its success; the group stays exactly where you put it — never removed at start-up, never
    recreated on activation, never counted in the zone report. This is undebuggable from the game:
    **a zone that "spawns nothing" is almost always a zone whose groups do not carry its name.**
    Check the prefix before looking anywhere else.

The corollary runs the other way, and is just as silent: a group that has nothing to do with the
zone, but sits inside the circle **and** is named `CZ-Alpha-…`, is part of it — and will be
destroyed at mission start along with the rest.

---

### Groups out of action {#out-of-action}

A group is not only alive or dead. An S-300 battery whose tracking radar is destroyed keeps its launchers, its trucks and its crew — and cannot fire.

The zone report now says so:

```
OUT OF ACTION (can no longer fight): CZ-Alpha-SA10
```

A group that has been wiped out does not appear there: it is simply gone from the remaining tallies. This line is only about groups **still standing** that have become harmless.

!!! note "This does not change when a zone ends"
    For now the information is advisory only: a zone still completes when **every** enemy unit is destroyed, useless launchers included. Ending the zone sooner is a separate design decision, not yet taken.

**How a group is judged.** By default a group counts as out of action if it is a SAM site (a search radar or a launcher is still standing) and no tracking radar is left. A vehicle that is its own radar and launcher — Tunguska, Tor, Osa — stays operational as long as it lives. A convoy has no radar at all: it remains a threat while it rolls.

For sites whose composition the DCS attributes cannot describe, a pattern table (`veaf.ImportantUnitsByGroupPattern`, in `veaf.lua`) declares the sets of units a site cannot do without and the minimum life, as a percentage, they need. The S-300 is already in it.

## Unit and Group Name Tags

Unit and group names in the DCS Mission Editor can carry special tags that control how VEAF handles them when the zone activates. Tags are embedded in the name and do not affect DCS itself.

| Tag | Example | Description |
|-----|---------|-------------|
| `#spawnradius=N` | `#spawnradius=200` | Scatter radius in metres around the group's recorded position. Without the tag, see [`#spawnradius`](#spawn-radius) |
| `#spawnchance=N` | `#spawnchance=50` | Percentage chance (0–100) this group will actually spawn. See [`#spawnchance`](#spawn-chance) |
| `#spawncount=N` | `#spawncount=2` | How many elements of one `#spawngroup` are **guaranteed** to spawn. See [`#spawncount`](#spawn-chance) |
| `#spawngroup="name"` | `#spawngroup="SAM"` | Override the spawn group name (useful to target a named template) |
| `#spawndelay=N` | `#spawndelay=120` | Delay in seconds before this group spawns after zone activation |
| `#command="cmd"` | `#command="-spawn sa-11"` | Execute a VEAF command instead of spawning this group; the unit acts as a trigger and is destroyed |
| `#alarm=N` | `#alarm=2` | Alarm state given to this group: `0` AUTO, `1` GREEN, `2` RED. Without the tag, the state follows the group's nature — see [`#alarm`](#alarm-state) |

### `#spawnradius` — the default dispersion {#spawn-radius}

With no tag, a group appears **scattered by 50 m** around its recorded position, and a static object appears **exactly** on its own. Dispersion exists so that a group does not respawn on the same metre twice; a static, on the other hand, is usually placed somewhere precise — a parking spot, a quay — where moving it would make no sense.

| What you write | What the group gets |
|---|---|
| nothing | 50 m for a group, 0 m for a static |
| `#spawnradius=200` | 200 m |
| `#spawnradius=0` | no dispersion — this is how you turn it off |

A `#command=` unit is **never** scattered, default or not: the command runs *at its position*, so moving it would move whatever it spawns. An explicitly written `#spawnradius=` does still apply to it.

!!! warning "This changes existing missions"
    From March 2023 to 6.15.14 the 50 m default was **unreachable**: the constant existed, the code meant to apply it never ran, and every group of a combat zone appeared exactly on its recorded position. A mission built during those three years will therefore see its groups move by about fifty metres. If a placement was precise on purpose, write `#spawnradius=0`.

#### The first waypoint follows the group {#waypoint-follows-group}

A scattered group no longer appears on its first waypoint, and the first waypoint is where a group sets off from. So it **moves with the group**, by the same distance in the same direction.

**The rest of the track stays put.** You placed those waypoints on roads, bridges and passes; shifting them fifty random metres would put them beside those features, and would draw a different track on every activation. A group therefore leaves from where it appeared and joins the route you drew.

Before 6.15.20 the first waypoint stayed at the editor position, so a scattered convoy drove back to fetch it first, walking a leg nobody had drawn. Mostly visible since 6.15.15, which made the 50 m dispersion effective.

#### A group straddling the zone's edge {#group-straddling-the-edge}

A zone adopts a group as soon as **one** of its units stands inside the circle: the whole group is then destroyed and recreated, units left outside included. That is deliberate, and it spares you having to frame a zone to the metre around a convoy.

What went wrong is that the zone anchored itself on **the first unit it could see** — so on the group's second unit whenever the first sat outside the circle. The entire group then appeared offset by the gap between those two units, a truck-length for a convoy, with no dispersion asked for and even with `#spawnradius=0`.

Since 6.15.21 the anchor is always the group's **first unit**, inside the circle or not. A group straddling the edge therefore appears where you drew it. If you had compensated for the offset by hand by moving your units, remove the compensation.

#### A value drawn from a range {#tag-ranges}

The four tags carrying a number — `#spawnradius`, `#spawnchance`, `#spawncount`, `#spawndelay` — accept a range instead of a fixed value, written the same way as in marker commands:

```
CZ-Alpha-CONVOY #spawnradius=100-300 #spawndelay=30-90
```

The value is drawn **once per mission**, when names are read at startup. Every activation of the zone therefore uses the same value: this varies placement from one game to the next, not from one activation to the next.

!!! warning "Before 6.15.23 a range was silently truncated"
    `#spawnradius=100-300` was read as `100`, with no message: you got the lower bound while believing you had a range. If you wrote any, they take effect now — so the radius may be larger than it used to be.

!!! note "`#alarm` takes no range"
    The alarm state is an enumeration (`0` AUTO, `1` GREEN, `2` RED): `#alarm=0-2` is not a random state, it is a typo. The tag refuses it as it already refuses an out-of-bounds value.

### Where tags are read from {#tag-sources}

A group's tags are the ones carried by **its own name and by the names of all its units**. Tagging a single truck of a convoy is therefore enough, whichever truck it is — no need to tag all four, and no need to guess which one DCS will process first.

Sources are read in a fixed order:

1. the **group** name;
2. the **unit** names, in **alphabetical** order.

The first value found for a tag wins. A later source stating a *different* value for the same tag is ignored and the log says so — two trucks of one convoy carrying `#alarm=0` and `#alarm=2` do not toss a coin: one wins and you are told. Repeating the *same* value on several units produces no message at all: that is the ordinary way of doing it.

!!! note "`#command` is the exception"
    `#command` stays attached to the object carrying it: every unit carrying one becomes its own trigger, which is what lets a group carry several commands. Put on the **group** name, it makes that group a **single** trigger rather than one per unit.

!!! warning "Before 6.15.14"
    Only the tags carried by whichever unit the engine met first counted, and tags on a group name were silently ignored. Since that order is not guaranteed, a tag put on a given truck worked or did not work for no visible reason.

### `#alarm` — making a group hold its ground {#alarm-state}

The ground alarm state decides two things at once, and both matter: a group on **RED** stops and deploys — radars up, ready to fire — while on **AUTO** it drives and lets DCS raise its alert on detection. Right for a SAM battery in one case, right for a convoy in the other, and never the same one.

**The zone therefore chooses by the nature of the group**, without you saying anything:

| The group | State it gets | Why |
|---|---|---|
| has a route to drive (more than one waypoint) | **AUTO** | so it leaves: on RED it would never move |
| stays put | **RED** | so it fights: on AUTO a SAM battery keeps its radars down |

`#alarm=N` still wins, in both directions — to pin a convoy in place (`#alarm=2`) as much as to keep a defence quiet until first contact (`#alarm=0`):

```
CZ-Alpha-SA6-BATTERY              ← RED, with nothing written
CZ-Alpha-SUPPLY-CONVOY            ← AUTO, with nothing written
CZ-Alpha-SA6-AMBUSH #alarm=0      ← quiet on purpose
```

An unreadable or out-of-range value (`#alarm=7`, `#alarm=x`) falls back to RED and says so in the log, rather than failing the zone.

!!! note "Only for mission groups"
    The tag applies to groups the zone spawns itself. On a `#command=` unit, pass the alarm state inside the command instead (`-spawn ..., alarm 2`), since the spawn is handled by the VEAF marker interpreter.

!!! warning "How this behaved before"
    Up to 6.15.4 zones spawned **every** group on RED, which is why a convoy placed in a zone never moved ([#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290)). The fix went through a single AUTO default, which sorted the convoys **and made the zones' air defences go silent** — a battery on AUTO does not light its radars. Hence the per-nature choice above. If you added `#alarm=2` to your batteries in the meantime, they still work and are now redundant: the default does the same thing.

### `#spawnchance` and `#spawncount` — the odds, or the number {#spawn-chance}

These two tags answer two different questions, and you have to pick which one you are asking.

`#spawnchance=N` is a **probability**, drawn once per group when the zone activates. `#spawnchance=50` spawns the group half the time; `#spawnchance=0` never spawns it; with no tag it always spawns (the default is 100).

`#spawncount=N`, paired with `#spawngroup`, is a **guarantee of a number**: "exactly N of these groups, every time". The zone draws which ones, then redraws as often as needed to reach N — so `#spawnchance` there only decides *which*, no longer *how many*.

```
CZ-Alpha-SA6-A #spawngroup="CZ-Alpha-SAM" #spawncount=2
CZ-Alpha-SA6-B #spawngroup="CZ-Alpha-SAM" #spawncount=2
CZ-Alpha-SA6-C #spawngroup="CZ-Alpha-SAM" #spawncount=2
CZ-Alpha-SA6-D #spawngroup="CZ-Alpha-SAM" #spawncount=2
```

Two of the four batteries, always two, drawn at random on every activation.

Without a `#spawngroup`, **each group is alone in its own**: its probability is drawn for it and for nothing else. A `#spawngroup` with no `#spawncount` goes on meaning "one of these", but every candidate now draws for the slot instead of being handed it.

!!! warning "This changes existing missions"
    Up to and including 6.17.0, `#spawnchance` could **not** deny a spawn. The zone redrew up to ten times and forced the draw on the last try, so a lone group always ended up spawning: the tag changed *when*, never *whether*. Even `#spawnchance=0` spawned. Redraws and the forced draw are now reserved for a `#spawncount` actually written, where they keep a promise of a number. **A mission in service that uses `#spawnchance` will therefore spawn fewer groups than before** — which is the behaviour this page has always described. If a group must spawn for certain, drop its tag or write `#spawnchance=100`.

### Practical example — MANPADS ambush

You want four MANPADS positions in a zone, but only about two should actually be occupied. Place four dummy infantry units named:

```
CZ-Alpha-MANPAD-1 #spawnchance=50
CZ-Alpha-MANPAD-2 #spawnchance=50
CZ-Alpha-MANPAD-3 #spawnchance=50
CZ-Alpha-MANPAD-4 #spawnchance=50
```

Each position has a 50% chance of spawning, independently of the others — statistically, around two will be active each time the zone is triggered. "Around" is the right word: sometimes none will spawn, and sometimes all four. If you want **exactly two** every time, `#spawncount` is the tag, as above.

### `#command` — spawning via VEAF marker syntax

The `#command` tag turns a unit into a one-shot trigger. When the zone activates, VEAF executes the command at the unit's position and destroys the unit. This is equivalent to dropping a map marker at that location.

```
CZ-Alpha-SPAWN-SA11 #command="-spawn sa-11, side red"
CZ-Alpha-CONVOY-TRIGGER #command="-convoy from ZONE-DEPOT to ZONE-FRONT"
```

This lets you set up complex spawns (SA-11 battery, convoys with AI routes) without any Lua code.

The trigger unit is a member of the zone like any other, so its name must
[start with the zone's name](#zone-membership) too. A unit called `SPAWN-SA11` sitting in `CZ-Alpha`
is never read, and its command never runs.

**A delayed command's groups belong to their zone.** A command can carry a delay in three ways — `-samsr!30` (an alias delay), a `-spawn`'s `delay` option, or a repeat. In all of them the command returns **before** anything has been spawned. What appears afterwards still belongs to the zone: deactivating the zone destroys those groups like any other.

Before 6.15.9 it did not. The zone read the list of what it had created too early, so a delayed group was registered nowhere and **outlived the zone that spawned it**.

> If the zone is deactivated while the delay is running, the group that appears afterwards is destroyed straight away — nothing can cancel an already scheduled spawn, so this is the outcome the deactivation would have produced.

Note that `#spawndelay` never had this problem: it delays the zone element itself, which registers on the way through.

---

## Spawned group names {#group-naming}

A group a combat zone creates does not carry the name you gave it in the editor. It looks like this:

```
[r]-Hydra Unit#10230
```

Three parts, two of which are there to stay:

| Part | What it is | Configurable? |
|------|------------|---------------|
| `[r]` / `[b]` / `[n]` | the group's coalition | no |
| `Hydra Unit` | **an invented name**, not yours | yes, see below |
| `#10230` | a unique identifier | no — DCS requires unique group names |

The invented name is deliberate: without it a player reads a zone's contents off the F10 map before
going anywhere near it. That is `veaf.HideNamesFromSpawnedGroups`, **on by default**.

To see the real names — while building or debugging a mission:

```yaml
mission:
  hide_names_from_spawned_groups: false
```

Names then read `<zone name> [r] <real name>#<id>`. The coalition tag and the identifier stay either way.

> The field exists from 6.15.34. Before that the setting was only reachable through
> `module_settings: { veaf.HideNamesFromSpawnedGroups: false }`, which still works.

---

## Module Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafCombatZone.SecondsBetweenWatchdogChecks` | `60` | How often the zone watchdog polls (s) |
| `veafCombatZone.SecondsBetweenSmokeRequests` | `180` | Smoke mark cooldown (s) |
| `veafCombatZone.SecondsBetweenFlareRequests` | `120` | Flare mark cooldown (s) |
| `veafCombatZone.RadioMenuName` | `"COMBAT ZONES"` | F10 submenu label |
| `veafCombatZone.DefaultSpawnRadiusForUnits` | `50` | Default unit scatter radius (m) |

---

## Defining a Zone

In the most common case, elements are populated automatically from the units placed inside the DCS trigger zone via `:addZoneElementsFromZoneNamed(...)`:

```lua
local strikeZone = VeafCombatZone:new()
  :setMissionEditorZoneName("CZ-Strike-Alpha")     -- DCS trigger zone name
  :setFriendlyName("Strike Alpha")                 -- radio menu label
  :setBriefing("Destroy all vehicles. Expect AAA and MANPADS.")
  :addZoneElementsFromZoneNamed("CZ-Strike-Alpha")
  :initialize()
```

You can also build and attach an element manually with `:addZoneElement(...)`:

```lua
local element = VeafCombatZoneElement:new()
  :setName("CZ-Strike-Alpha-ARMOR")
  :setDcsGroup(true)
  :setSpawnGroup("CZ-Strike-Alpha-ARMOR")    -- DCS group name to spawn
  :setSpawnRadius(100)

strikeZone:addZoneElement(element)
```

### VeafCombatZone Builder Methods

| Method | Description |
|--------|-------------|
| `:setMissionEditorZoneName(name)` | DCS trigger zone that defines the spawn area |
| `:setFriendlyName(name)` | Label shown in the radio menu |
| `:setBriefing(text)` | Full briefing text |
| `:setOnCompletedHook(fn)` | Callback when all enemies destroyed |
| `:addZoneElement(element)` | Add an element to the zone |
| `:addZoneElementsFromZoneNamed(zoneName)` | Populate elements from the units of a trigger zone |
| `:addSpawnedGroup(groupOrName)` | Register an already-spawned group as belonging to the zone |
| `:setActive(bool)` | Activate the zone at start |
| `:setTraining(bool)` | Training mode |
| `:setCompletable(bool)` | Whether the zone can be marked as completed |
| `:enableUserActivation()` / `:disableUserActivation()` | Allow/forbid player activation |
| `:setRadioGroupName(name)` | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
| `:setRadioMenuPrefix(text)` | Prefix displayed before the zone name in the menu |

### VeafCombatZoneElement Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Element name |
| `:setPosition(pos)` | Element position |
| `:setDcsGroup(bool)` | The element references a DCS group |
| `:setDcsStatic(bool)` | The element references a DCS static object |
| `:setSpawnGroup(name)` | DCS group name to spawn |
| `:setVeafCommand(cmd)` | VEAF command to run instead of a spawn |
| `:setRoute(route)` | Element AI route |
| `:setCoalition(side)` | Element coalition |
| `:setSpawnRadius(m)` | Scatter radius around zone centre |
| `:setSpawnChance(pct)` | Spawn probability (0–100) |
| `:setSpawnCount(n)` | Number of instances to spawn |
| `:setSpawnDelay(s)` | Delay before spawn (seconds) |

---

## F10 Radio Menu (per zone)

- **Activate** — spawn the zone's unit groups
- **Deactivate** — despawn units, reset the zone
- **Info** — status, remaining unit count, briefing
- **Smoke** — mark zone with smoke (cooldown applies)
- **Flare** — mark zone with flares

> **Security:** activate and deactivate commands are secured by default: the group acts at the level of its lowest-graded occupant (see [veafSecurity](veafSecurity.en.md)). [Training mode](#training-mode) removes this restriction. Info, smoke, and flare requests are always accessible to everyone.

### Radio menu options

| Method | Description |
|--------|-------------|
| `:disableRadioMenu()` | Disable the radio menu entirely for this zone |
| `:setRadioMenuPrefix(text)` | Prefix displayed before the zone name in the menu |
| `:setRadioGroupName(name)` | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
| `:setEnableSmokeAndFlare(bool)` | Enable/disable smoke and flare requests (default: `true`) |
| `:setShowUnitsList(bool)` | Include remaining unit list in the info message (default: `true`) |
| `:setShowZonePositionInfo(bool)` | Include zone coordinates and weather in the info message (default: `true`) |

### Wreck cleanup

By default, vehicle wrecks and corpses are automatically removed when a zone is deactivated. To keep them:

```lua
:disableJunkCleanup()
```

---

## Operations (Grouped Zones)

Multiple zones can be grouped into an **Operation** that completes when all child zones are done:

```lua
local operation = VeafCombatOperation:new()
  :setMissionEditorZoneName("OP-THUNDER")
  :setFriendlyName("Operation Thunder")
  :setBriefing("Destroy both armour columns before they reach Senaki.")

operation:addTaskingOrder(alphaZone)                 -- first task
operation:addTaskingOrder(bravoZone, { "OP-THUNDER-ALPHA" })  -- unlocked after Alpha
operation:initialize()
```

`VeafCombatOperation = VeafCombatZone:new()` — the operation extends `VeafCombatZone`. Tasks are added with `:addTaskingOrder(zone, requiredComplete)`, where `zone` is a `VeafCombatZone` and `requiredComplete` is the optional list of zone names that must complete before this one is activated. The operation appears in the radio menu as a single entry.

---

## Zone Chaining

A zone can automatically activate one or more follow-on zones when it is completed. This lets you build dynamic campaign progressions without manual scripting:

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("CZ-Alpha")
  :setFriendlyName("Strike Alpha")
  :addChainedCombatZone("Strike Bravo")     -- triggers when Alpha is done
  :addChainedCombatZone("Strike Charlie")   -- one is chosen at random
  :setChainedCombatZonesDelay(60)           -- wait 60 s before chaining
  :initialize()
```

When multiple chained zones are defined, **one is picked at random** — useful for branching narratives or avoiding predictability.

| Method | Description |
|--------|-------------|
| `:addChainedCombatZone(name)` | Add a zone to trigger after completion |
| `:setChainedCombatZonesDelay(s)` | Seconds to wait before chaining (default: 0) |

---

## Training Mode

Setting a zone to training mode changes two things:

- **No security**: any player can activate or deactivate the zone via the radio menu (normally these commands are restricted to the group's effective level — see [veafSecurity](veafSecurity.en.md)).
- **Verbose status**: the zone info message lists remaining units and their approximate positions (using smoke or bearings), giving pilots a clear picture of what is left.

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-TRAINING-A")
  :setFriendlyName("Training-A")
  :setTraining(true)
  :initialize()
```

Training mode is ideal for BFM / CAS training scenarios where pilots need to know unit positions.

---

## See Also

- [veafCasMission](veafCasMission.en.md) — generated CAS zones (no pre-placed groups needed)
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafCombatZone` API
