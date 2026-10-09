# veafQraManager — Quick Reaction Alert


**Module ID:** `QRA` | **File:** `veafQraManager.lua`

> **See it in game**: step 10 “Sukhumi QRA” of the [demo mission](https://github.com/VEAF/VEAF-Demo-Mission-v6/blob/main/README.en.md#the-guided-tour).

---

## Purpose

Defines protected airspace zones defended by AI interceptors. When a hostile aircraft enters the zone, a QRA flight is scrambled. Once the QRA is destroyed, the zone is undefended until it resets (when all intruders have left). Supports multiple groups, rearming, airbase dependency, radio status messages, and a logistics chain (limited aircraft count with optional resupply).

---

## Dependencies

- `veafRadio` — status messages (optional)
- `veafSpawn` — AI group spawning

---

## Enable

### Via `mission.yaml` (recommended)

`veafQraManager.initialize()` is called automatically by the framework.

### Via `mission-script.lua`

Call `veafQraManager.initialize()` **before** declaring any QRA zone:

```lua
veafQraManager.initialize()
```

> **Important:** without this call, `S_EVENT_BIRTH` and `S_EVENT_PLAYER_ENTER_UNIT` events are not listened to. Players joining via a dynamic slot will be invisible to QRAs and will not trigger any scramble.

Each QRA zone is then created and activated individually with `:start()`:

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA")
  :start()
```

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

QRA definitions live **under `modules.QRA`** (`silence_all` + `definitions:`). The `QRA` module must be enabled in `modules:`.

```yaml
modules:
  QRA:
    silence_all: false      # true = suppress all QRA radio messages globally
    definitions:
      - name: "QRA-North"                 # REQUIRED — identifier and radio prefix
        coalition: RED                    # REQUIRED — RED | BLUE
        enemy_coalitions: [BLUE]          # coalitions that trigger a scramble
        trigger_zone: "ZONE-QRA-NORTH"   # DCS trigger zone defining the airspace
        zone_radius: 30000               # radius in metres (alternative to trigger_zone)
        # simple_groups: ["MiG-29 QRA Flight"]  # OR a plain list, always scrambled — never with
        #                                       # groups_by_enemy_count, beside which it never takes off
        groups_by_enemy_count:           # scale response to intruder count
          - enemy_count: 1               # scramble when 1 intruder detected
            groups: ["Pair-1", "Pair-2"] # group pool
            random_pick: 1               # draw 1 group from the pool (without random_pick: all take off)
          - enemy_count: 3
            groups: ["Pair-1", "Flight-2"]   # no random_pick: both take off
        delay_before_rearming: 30        # seconds before zone resets after intruders leave
        rearm_while_occupied: true       # rearm without waiting for the zone to clear
        scale_with_opposition: true      # tier also chosen from the opposition level
        delay_before_activating: 30      # seconds after :start() before QRA goes online
        react_on_helicopters: false      # true = also trigger on enemy helicopters
        airport_link: "Batumi"           # paused while this airbase is lost (shortcut for links)
        # links: ["Batumi", "SA-10 North"]  # airbases, FARPs, ships, groups or statics the QRA depends on
        # follow_unit: "CVN-74"             # the zone follows this unit (a carrier, for instance)
        logistics:                       # a finite stock of aircraft (without this block: unlimited)
          groups_available: 4            # groups in stock at the start
          resupply_delay: 1800           # one resupply every 30 min
```

### `modules.QRA` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `silence_all` | boolean | `false` | No | Suppress all QRA radio messages globally |
| `definitions` | object[] | `[]` | No | List of QRA zone definitions |

### `definitions[]` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier and radio prefix |
| `coalition` | string | — | Yes | Defending coalition: `RED` or `BLUE` |
| `enemy_coalitions` | string[] | *(opposite)* | No | Coalitions that trigger a scramble |
| `trigger_zone` | string | — | No | DCS trigger zone name |
| `zone_radius` | integer | — | No | Zone radius in metres (when no trigger zone) |
| `simple_groups` | string[] | `[]` | No | DCS group names to always scramble, or VEAF commands (`[0,0]-spawn shilka, country russia`, `-sa6`): an entry starting with `[` or `-` is a command, and `validate` does not look for it in the mission. **Without** `groups_by_enemy_count`: beside it, these groups never take off (a level-1 rule replaces them, a lowest level above 1 keeps level 1 from firing), and `validate` says so |
| `groups_by_enemy_count` | object[] | `[]` | No | Scaled scramble rules |
| `groups_by_enemy_count[].enemy_count` | integer | — | Yes | Number of intruders that activates this rule |
| `groups_by_enemy_count[].groups` | string[] | — | Yes | Pool of group names or VEAF commands, as for `simple_groups` |
| `groups_by_enemy_count[].random_pick` | integer | — | No | How many groups to **draw** from the pool, without replacement: never the same group twice, never more than the list holds. **Absent: every group of the tier takes off.** The tier used is the biggest whose `enemy_count` does not exceed the intruders, whatever order the tiers are written in |
| `delay_before_rearming` | integer | `0` | No | Seconds before zone resets after intruders leave |
| `delay_before_activating` | integer | `0` | No | Seconds after start before QRA goes online |
| `rearm_while_occupied` | boolean | `false` | No | A destroyed QRA rearms **even with intruders still in its zone**. Without it, it waits for the zone to be empty — with several players over the target, almost never |
| `scale_with_opposition` | boolean | `false` | No | Choose the tier from the [opposition level](#opposition-level) when it exceeds the intruders in the zone — the lowest tier's threshold too: a pair triggers a QRA whose first tier is 3 when the mission is sized for six. The trigger stays on the zone: nobody in it, no scramble |
| `react_on_helicopters` | boolean | `false` | No | Also trigger on enemy helicopters |
| `active_at_start` | boolean | `true` | No | `false`: the QRA is declared but **not armed** at start — it waits for a `qra.start` (radio menu) or a scripted call |
| `airport_link` | string | — | No | Name of a linked DCS airbase: the QRA pauses while the airbase is captured or too damaged, and resumes when it is retaken. Shortcut for one entry of `links` |
| `links` | string[] | `[]` | No | What the QRA depends on: airbases, FARPs, ships, groups or statics, by DCS name. A lost airbase or FARP **pauses the QRA** until it is retaken; a ship, group or static destroyed **stops it for good**. One lost link is enough |
| `follow_unit` | string | — | No | Name of a unit the zone follows (a carrier, for instance); the centre is read again on every check. A trigger zone linked to a unit in the editor follows it too, without this key. If the unit dies, the zone stays where it last saw it |
| `logistics` | object | — | No | A finite stock of aircraft and its resupply — see [Logistics chain](#logistics-chain) |
| `respawn_default_offset` | [number, number] | `[0, 0]` | No | Offset in metres `[north, east]` from the zone centre where an element deployed by a VEAF command with no `[x,y]` of its own appears |
| `radio_menu` | boolean | `false` | No | Automatically generate an F10 radio submenu to control this QRA (see below) |
| `radio_menu_restrict_to_group` | string | — | No | Name of a DCS group; the generated submenu only appears for that group |
| `radio_menu_secured` | boolean | `false` | No | **Secured** commands: only a pilot of that group with the required security level can run them. Requires `radio_menu_restrict_to_group` (the level checked is that of the group the menu is posted for); the build refuses otherwise |

### Control radio menu (shortcut)

QRA start/stop commands **do not exist** in the standard VEAF radio menu (unlike CombatZone or Carrier). To give the Mission Master F10 control over a QRA, add `radio_menu: true` to its definition: the framework automatically generates a submenu named after the QRA, with "Start &lt;name&gt;" and "Stop &lt;name&gt;" commands.

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-North"
        coalition: RED
        trigger_zone: "ZONE-QRA-NORTH"
        simple_groups:
          - "MiG-29 QRA North"
        radio_menu: true                         # generates the control submenu
        radio_menu_restrict_to_group: "MM Ctrl"  # optional: restrict the submenu to this DCS group
        radio_menu_secured: true                 # optional: and require the security level ("+…" commands)
```

!!! warning "This menu is not secured"
    Without `radio_menu_restrict_to_group`, the submenu is posted for **every player**, on both sides,
    and its commands run without asking for any security level. On a public server, a blue pilot can
    stop the red QRA they are about to fly over. Keep it for a Mission Master group with
    `radio_menu_restrict_to_group` — knowing that any player who takes that group's slot sees the menu
    in turn — and add `radio_menu_secured: true` so that pilot must also hold the required security level.

This is **mechanism 1** (per-module shortcut). For a custom MM menu that is structured or combines several actions (QRA, AirWaves, flags, messages, Lua), use **mechanism 2** described in [veafRadio → Radio menus in YAML](veafRadio.en.md#radio-menus-in-yaml).

### Sizing the opposition to the number of players {#opposition-level}

Tiers by `enemy_count` answer **what enters the zone**. A pair showing up ahead of a six-ship package gets a pair's tier, while the other four are still away. The **opposition level** says how many player aircraft the enemy fighters are sized for, in the same unit as `enemy_count`; a QRA set to `scale_with_opposition: true` takes the tier of the bigger of the two numbers.

```yaml
opposition:                 # a root block of mission.yaml, beside modules:
  level: 6                  # sized for 6 player aircraft
  follow: air_to_air        # off (default) | air_to_air: players on CAP | players: connected | airborne: in the air
  lower_after: 300          # seconds a lower count must hold before the level drops
  players_coalition: BLUE   # BLUE (default) | RED: the coalition whose players are counted
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `level` | integer ≥ 0 | — | The level at start. With neither a level nor a follow mode, QRAs answer their zone alone |
| `follow` | string | `off` | `air_to_air`: the level follows the players **airborne carrying at least one radar-guided air-to-air missile** (Fox 1 or Fox 3) — the ones flying CAP; `players`: every player of the coalition connected, helicopters and ground-attack aircraft included; `airborne`: every one in the air. Re-read every 60 s |
| `lower_after` | seconds | `300` | A rise is taken **at once** (a player who joins must be served); a drop only once the count has stayed lower for this long — a disconnect, or a crash and respawn, changes nothing |
| `players_coalition` | string | `BLUE` | The coalition whose players are counted |

The block also adds, in game:

- an **Opposition** radio menu: *Current level* (for everyone), *Level* → "1 player(s) on CAP" … "8 player(s) on CAP", which sets the level in one click and stops following, and *Mode* → the follow mode (secured commands);
- an **`_opposition`** marker, for the *SENIOR_PILOT* security level: `_opposition 6` sets the level (and stops following), `_opposition air_to_air` / `_opposition players` / `_opposition airborne` / `_opposition off` changes the mode, `_opposition` alone announces it;
- in the [combat missions](veafCombatMission.en.md) menu, under each skill, an **Auto scale** entry that activates the scale of one enemy group per two players (rounded up), within the scales offered.

Every change of level is announced to everybody.

**How to choose.** Write the tiers up to the package size you expect: for 5 to 7 players, for instance `1` → a pair, `3` → two pairs, `5` → three. Never a single fixed pair against 5 players or more. Then:

- an evening whose attendance you know → a fixed `level`;
- attendance unknown, or changing during the flight → `follow: air_to_air`: only the players on CAP count, not the ones who came for ground attack, helicopters or transport;
- every player must count, whatever their role → `follow: players`, or `follow: airborne` to count only those in the air.

`air_to_air` reads the weapons **in flight** (`getAmmo`): what the aircraft carries at that moment, so what the pilot chose when rearming, not the loadout the mission placed.
Two self-defence AIM-9 on a bomb truck do not count; neither does a fighter carrying infrared missiles only.
A multirole on ground attack that keeps two AIM-120 for escort does count: the *Level* menu corrects the count on the evening it is wrong.

A campaign writes this block itself from its `players` or `campaign next --players` — see [Campaigns](../CAMPAIGN.en.md#players).

### Minimal example

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-Sud"
        coalition: RED
        trigger_zone: "ZONE-QRA-SUD"
        simple_groups:
          - "Su-27 Intercept"
```

---

## VeafQRA Builder Methods

All setters return `self` and can be chained. Call `:start()` at the end to activate.

### Identification

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier — also used as message prefix if no description is set |
| `:setDescription(text)` | Human-readable label used in radio messages (defaults to name) |

### Zone Definition

Use one of the following to define the protected airspace:

| Method | Description |
|--------|-------------|
| `:setTriggerZone(zoneName)` | DCS trigger zone name (preferred) |
| `:setZoneCenter(vec3)` | Manual center point (DCS vec3) — use with `:setZoneRadius()` |
| `:setZoneCenterFromCoordinates(coordStr)` | Center from a `"lat,lon"` string |
| `:setZoneRadius(meters)` | Radius in meters when not using a trigger zone |
| `:setFollowUnit(unitName)` | The zone follows this unit, a carrier for instance |

### Defenders

| Method | Description |
|--------|-------------|
| `:addGroup(name)` | Add a DCS group name to scramble (call multiple times for multiple groups) |
| `:addRandomGroup(groups, number, bias)` | Randomly pick `number` groups from a list |
| `:setGroupsToDeployByEnemyQuantity(n, groups)` | Scale response: deploy **every** group of `groups` when at least `n` enemies are in zone (the biggest tier reached wins) |
| `:setRandomGroupsToDeployByEnemyQuantity(n, groups, number, bias)` | The same, drawing `number` groups without replacement |

### Coalition

| Method | Description |
|--------|-------------|
| `:setCoalition(side)` | Coalition that owns this QRA (e.g. `coalition.side.RED`) |
| `:addEnnemyCoalition(side)` | Add an enemy coalition (defaults to the opposite of the defending coalition) |

### Behavior

| Method | Description |
|--------|-------------|
| `:setSilent(bool)` | Suppress all radio status messages for this QRA |
| `:setDrawZone(bool)` | Draw the protected zone on the map |
| `:setReactOnHelicopters()` | Also trigger on enemy helicopters (planes only by default) |
| `:setDelayBeforeRearming(seconds)` | Delay before the QRA resets after all intruders leave (`-1` = no delay) |
| `:setNoNeedToLeaveZoneBeforeRearming()` | Allow rearming even if enemies are still in the zone (`rearm_while_occupied`) |
| `:setScaleWithOpposition()` | Choose the tier from the opposition level when it exceeds the intruders (`scale_with_opposition`) |
| `:setResetWhenLeavingZone()` | Reset immediately the moment all enemies leave (no wait) |
| `:setDelayBeforeActivating(seconds)` | Delay before the QRA goes online after `:start()` |
| `:setMinimumAltitudeInFeet(feet)` | Minimum enemy altitude to trigger a scramble |
| `:setMaximumAltitudeInFeet(feet)` | Maximum enemy altitude to trigger a scramble |
| `:setRespawnDefaultOffset(latDelta, lonDelta)` | Spawn offset from zone center (meters, lat/lon) — first number north, second east; see [veafAirWaves](veafAirWaves.en.md#spawn-offset) |
| `:setRespawnRadius(meters)` | Scatter radius around spawn point (minimum 250 m) |

### Links

| Method | Description |
|--------|-------------|
| `:addLink(name)` | Make the QRA depend on an airbase, FARP, ship, group or static: a lost airbase pauses it, anything else destroyed stops it |
| `:setAirportLink(name)` | Link to an airbase — the QRA pauses while the airbase is lost (shortcut for `:addLink`) |
| `:setAirportMinLifePercent(pct)` | Minimum airbase health for QRA to remain active (0–1, default `0.9`) |

### Messages and Callbacks

All message strings accept `%s` as a token for the QRA name/description. Callbacks receive the QRA instance as their first argument.

| Method | Triggered when |
|--------|---------------|
| `:setMessageStart(text)` / `:setOnStart(fn)` | QRA goes online |
| `:setMessageDeploy(text)` / `:setOnDeploy(fn)` | QRA scrambles |
| `:setMessageDestroyed(text)` / `:setOnDestroyed(fn)` | QRA shot down |
| `:setMessageReady(text)` / `:setOnReady(fn)` | QRA ready after rearming |
| `:setMessageOut(text)` / `:setOnOut(fn)` | No more aircraft available |
| `:setMessageResupplied(text)` / `:setOnResupplied(fn)` | Logistics resupply complete |
| `:setMessageAirbaseDown(text)` / `:setOnAirbaseDown(fn)` | Linked airbase destroyed |
| `:setMessageAirbaseUp(text)` / `:setOnAirbaseUp(fn)` | Linked airbase restored |
| `:setMessageStop(text)` / `:setOnStop(fn)` | QRA goes offline |

### Warehousing / Logistics

By default the QRA has unlimited aircraft. Use these to simulate a finite stock with optional resupply:

| Method | Description |
|--------|-------------|
| `:setQRAcount(n)` | Total aircraft groups available (`-1` = infinite) |
| `:setQRAmaxCount(n)` | Max groups active at once (`-1` = infinite) |
| `:setQRAresupplyDelay(seconds)` | Seconds before a resupply cycle starts |
| `:setQRAmaxResupplyCount(n)` | Maximum number of resupply cycles (`-1` = infinite) |
| `:setQRAminCountforResupply(n)` | Remaining count that triggers a resupply |
| `:setResupplyAmount(n)` | Groups added per resupply cycle (default `1`) |

### Lifecycle

| Method | Description |
|--------|-------------|
| `:start()` | Activate the QRA — broadcasts `messageStart` and starts the watchdog |
| `:stop(silent)` | Deactivate the QRA — broadcasts `messageStop` unless `silent` is `true` |

---

## How it works

A QRA zone monitors a volume of airspace defined by a DCS trigger zone. The moment a hostile aircraft enters that space, the QRA scrambles — provided it is ready. When the QRA is shot down, the zone enters a rearming state; it will become active again once the enemies leave and the rearm timer expires.

### State machine

```
STOP ──start()──► READY ──(intruder enters)──► ACTIVE ──(QRA destroyed)──► DEAD
  ▲                 ▲                                                          │
  │                 └──────────(all intruders left + rearm delay)─────────────┘
  │                                                     │
  └──────────────────────────stop()────────────────────►┘
```

Full states:

| State | Meaning |
|-------|---------|
| `STOP` | Inactive — `stop()` was called or the QRA was never started |
| `READY` | Armed and watching for intruders |
| `READY_WAITINGFORMORE` | QRA scrambled; additional intruders triggered deployment of more groups |
| `ACTIVE` | QRA is airborne and intercepting |
| `DEAD` | QRA was destroyed; waiting for conditions to rearm |
| `WILLREARM` | Rearming timer is running |
| `OUT` | No more aircraft available (stock exhausted) |
| `NOAIRBASE` | A linked airbase is captured or too damaged — the QRA waits for it to be retaken |

### Setting up in the DCS Mission Editor

1. **Create a trigger zone** — draw the airspace you want to protect. Name it something memorable, e.g. `ZONE-QRA-NORTH`.
2. **Place the QRA group** — create the aircraft group that will scramble. Set it to **Late Activation** so it does not spawn at mission start (VEAF handles activation). Give the group a distinctive name, e.g. `MiG-29 QRA North`.
3. **Wire it up** — the recommended approach is `mission.yaml` (no Lua required); the `mission-script.lua` equivalent is shown next.

**Via `mission.yaml`** (recommended) — add the definition under `modules.QRA`:

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-North"
        coalition: RED
        trigger_zone: "ZONE-QRA-NORTH"
        simple_groups:
          - "MiG-29 QRA North"
```

> A definition listed under `definitions:` is started automatically when the mission loads. To delay when it comes online, use `delay_before_activating`; to declare it **without arming it**, set `active_at_start: false` (it can then be armed by a `qra.start` radio command or a script); to drop it entirely, remove it from `definitions:`.

**Via `mission-script.lua`** — call the builder after `veafQraManager.initialize()`, then `:start()` explicitly:

```lua
VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA North")
  :start()
```

That is all — no trigger conditions, no scheduled functions. VEAF handles detection, scramble, and rearm automatically.

### What a scrambled group does {#scrambled-group-task}

A group whose **task** (in the editor) is `CAP` or `Intercept` gets its job from the script when its route
does not give it one: if it carries no aircraft engagement task (`EngageTargets` or `EngageTargetsInZone`
with *Air* targets), it is launched on **zone defense**:

- it appears where you placed it, with the options of its first waypoint (ROE, reaction to threat…);
- it flies to the QRA zone and holds a race-track centred on it, along the axis it arrives from (a 20 NM
  leg, or the zone's diameter when that is shorter);
- it engages only the aircraft that enter the zone, which it ranks by type and distance.

A group placed **on a parking spot or the runway** keeps its take-off as you set it, then climbs to
27,000 ft for its patrol.

**On the runway by default.** A QRA really takes off from its field: that is the start the MCP action `create_qra` lays down when told nothing (the coalition's airfield nearest the zone, or the one named), an air start only when asked.
What it costs:

- **the time to get airborne** before reaching the zone — to be measured in game, not estimated here;
- **a field too damaged or taken** (below `airbaseMinLifePercent`) keeps the QRA on the ground (`NOAIRBASE`): in a campaign, striking the enemy's field is a way to ground its QRA, and that is intended;
- **a unit on the runway** keeps it from rolling: a campaign's garrisons are kept off the concrete for that reason.

So this is the normal case: place the interceptor with **a single waypoint** and no task, and the script
does the rest; the build says so for every such group. If you want a flight plan of your own, write it **with** an aircraft engagement task: it is
then flown as written. A hand-written route without that engagement is replaced, and the build warns you
about it. A group with any other task (`CAS`, `Ground Attack`, `Escort`…) always flies its route.

A `-cap` command listed in `simple_groups` also defends the QRA zone, not the 60 NM zone it draws around
its own leg.

### Logistics chain {#logistics-chain}

By default a QRA has unlimited aircraft. The logistics system lets you model a finite airfield stock with optional resupply — useful for long persistent missions:

| Parameter | Role |
|-----------|------|
| `setQRAcount(n)` | Total aircraft groups available (acts as the current stock) |
| `setQRAmaxCount(n)` | Hard cap on simultaneous active groups |
| `setQRAresupplyDelay(s)` | Seconds to wait before a resupply starts |
| `setQRAminCountforResupply(n)` | Stock level that triggers a resupply |
| `setQRAmaxResupplyCount(n)` | Maximum number of resupply cycles (`-1` = unlimited) |
| `setResupplyAmount(n)` | Groups added per resupply cycle (default `1`) |

Think of it as a warehouse: `QRAcount` is what is on the shelf, `resupplyDelay` is the truck delivery time, and `minCountforResupply` is the reorder point.

In `mission.yaml`, the `logistics:` block of a definition sets the same things, one key per method:

| `logistics` key | Method | Role |
|-----------------|--------|------|
| `groups_available` | `setQRAcount` | Groups in stock at the start; at `0`, the QRA starts empty and waits for a resupply |
| `max_ready` | `setQRAmaxCount` | Ceiling of groups in stock |
| `resupply_delay` | `setQRAresupplyDelay` | Seconds between the order and the delivery |
| `resupply_amount` | `setResupplyAmount` | Groups delivered by each resupply |
| `max_resupplies` | `setQRAmaxResupplyCount` | Groups deliverable in total (`-1` = unlimited, `0` = no resupply) |
| `resupply_below` | `setQRAminCountforResupply` | Stock below which a resupply leaves; absent, it leaves as soon as a group is lost |

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-LIMITED"
        coalition: RED
        trigger_zone: "ZONE-LIMITED"
        simple_groups: ["F-15C QRA 1", "F-15C QRA 2"]
        logistics:
          groups_available: 4
          max_ready: 2
          resupply_delay: 1800
          resupply_amount: 1
```

`validate` reports a `logistics` key it does not know.

---

## Global Configuration

| Constant | Default | Description |
|----------|---------|-------------|
| `veafQraManager.WATCHDOG_DELAY` | `5` | Check interval in seconds |
| `veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT` | `10` | Minimum QRA unit life before considered destroyed |
| `veafQraManager.DEFAULT_airbaseMinLifePercent` | `0.9` | Default airbase health threshold |
| `veafQraManager.AllSilence` | `false` | Globally suppress all QRA messages |

---

## Example: Multiple QRA Zones

```lua
-- Northern zone defended by MiG-29s, tied to Beslan airbase
VeafQRA:new()
  :setName("QRA-NORTH")
  :setTriggerZone("ZONE-NORTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29S QRA North-1")
  :addGroup("MiG-29S QRA North-2")
  :setAirportLink("Beslan")
  :setDelayBeforeRearming(600)
  :start()

-- Southern zone, always active, silent
VeafQRA:new()
  :setName("QRA-SOUTH")
  :setTriggerZone("ZONE-SOUTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("Su-27 QRA South")
  :setSilent(true)
  :start()
```

### Example: Finite stock with resupply

```lua
-- 4 groups total, max 2 active at once, resupply 1 group every 30 min
VeafQRA:new()
  :setName("QRA-LIMITED")
  :setTriggerZone("ZONE-LIMITED")
  :setCoalition(coalition.side.RED)
  :addGroup("F-15C QRA 1")
  :addGroup("F-15C QRA 2")
  :setQRAcount(4)
  :setQRAmaxCount(2)
  :setQRAresupplyDelay(1800)
  :setResupplyAmount(1)
  :start()
```

---

## See Also

- [veafAirWaves](veafAirWaves.en.md) — wave-based AI attack system (vs QRA which is defensive)
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafQraManager` API
