# Persistent campaign

> One mission that runs on a server for weeks, in the spirit of Foothold: zones that change hands, a front that moves on its own, enemy air, credits to spend, and a save that resumes where the server stopped.
> Built on the VEAF tools and scripts alone, without Moose.
> It is the other mode of the [multi-mission campaign](CAMPAIGN.en.md): same `campaign.yaml`, same zones, same garrisons, but the campaign moves during the flight rather than between two missions.

## What the players see {#players}

- **The F10 map** shows each zone as a circle in its owner's colour, with its name and its garrison's state, and the connections between zones.
  An enemy zone reads "strength unknown" until it has been [reconnoitred](#intel).
- **A zone never changes hands directly**: when its garrison is destroyed it turns **neutral** (grey).
  A neutral zone is taken by holding the ground: ground units of a single side staying there for `capture_seconds` (120 s by default) — CTLD 2 troops or crate, a convoy, a `_spawn` group, a Combined Arms vehicle, a **landed** helicopter.
  The new garrison appears at once.
- **Slots follow the bases**: an airfield taken goes to the side that took it, with its dynamic slots.
- **The front moves on its own**: the enemy [counter-attacks](#front), reinforces its zones by helicopter, and sends CAP, strikes and [bombers](#bombers).
- **The enemy pays for what it sends** with the [resources](#resources) its factories make: destroying its [factories](#zone-kinds) or cutting its [supply network](#network) grounds its CAP in the end.
- **The map is tinted** by side, each zone holding the [territory](#territory) nearest to it, and the front reads between the two colours.
- **The F10 → Other → Campaign menu** gives the situation, the credits, the tasks, the intelligence and the shop.
- **The game ends** when one side holds no zone left: a victory if it is the enemy, a defeat if it is us.
  Everyone is told, and the campaign starts afresh at the next load of the mission.

## Declaring a persistent campaign {#declare}

It is a [multi-mission campaign](CAMPAIGN.en.md#declare) `campaign.yaml` with `mode: persistent`, and, when needed, a `dynamic:` block.
The objectives and the number of missions play no part: winning is holding every zone.

```yaml
campaign:
  name: Georgian Front
  theatre: Caucasus
  era: MODERN
  mode: persistent
  player_side: blue

zones:
  - { name: Kobuleti, at: { airfield: Kobuleti }, size: airfield, side: blue, radius: 3000 }
  - { name: Poti, at: { lat: 42.155, lon: 41.705 }, size: outpost, side: neutral }
  - { name: Senaki, at: { airfield: Senaki-Kolkhi }, size: airfield, side: red, radius: 3000 }

connections:
  - [Kobuleti, Poti]
  - [Poti, Senaki]

dynamic:            # all optional: every key has its default, below
  wake_radius: 60000
  economy:
    start_credits: 500
```

A complete example, ready to copy, ships with the tools: [`src/defaults/campaign-folder-persistent/campaign.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/defaults/campaign-folder-persistent/campaign.yaml).

Without a `sides:` block, a side keeps no reserve: its garrisons are drawn without limit.
With a reserve, it empties as in a multi-mission campaign, and a side with nothing left only fields token garrisons.

### Building the mission {#build}

```powershell
.\veaf-tools.exe campaign init C:\Campaigns\Georgia
.\veaf-tools.exe campaign next C:\Campaigns\Georgia
```

Then the mission of the `missions\mission-01\mission` folder is built like any mission, and put on the server.
`campaign next` run again on the same folder updates it without touching the rest of the work done in it.
`campaign apply` has no use here: there is no "between two missions".

`campaign next` also adds to the mission's `ctld-config.yaml` what the players carry for the campaign: the **"Zone supplies"** crate (one per side), the **"Spy"** troop group (one man) and the **"Sappers"** group (two men, the [demolition team](#demolition)).
It also enforces the "fog of war" F10 view (`mission.forced_options.f10_view: fog_of_war`): a pilot sees only the enemies their side has detected, and a garrison's strength is learned by [reconnaissance](#intel). A view already chosen in `mission.yaml` is kept.

**No interpreter command in a persistent campaign.**
A unit named `#veafInterpreter["…"]` in the Mission Editor spawns its units afresh at every start of the mission: in a persistent campaign, they come back whole after each server restart, their losses forgotten, paid by nobody.
What the campaign must hold is declared in `campaign.yaml`, as a zone with its garrison (an explicit `garrison:` list when the composition matters): the zone is saved with its losses, and the [network](#network) rebuilds it at its side's expense.
`campaign next` reports the interpreter commands it finds in the mission.

## The save {#save}

The mission writes its state every `save_seconds` (60 s) and at mission end to:

```text
<Saved Games>\DCS\Missions\Saves\<campaign name>\persistent.state
```

At start it reads that file back: each zone takes back its owner, its garrison with its losses and its capture in progress, a factory its buildings standing or destroyed, an airfield its weapon stocks; the credits, each side's resources and the current intelligence come back too.
A zone added to `campaign.yaml` since starts from its declared state; a zone removed is ignored, and the log says so.

What is **not** restored after a restart: the aircraft, helicopters and convoys under way. They are lost; the zones and garrisons are not, and the survivors of a convoy paid from a reserve go back to it.
What survives comes home: an assault convoy, a paid spawn still standing or a delivery of the network on its way when the server stopped pay their price back into their side's resources at the next load.

The file is a Lua table read with no access to anything: it cannot run code.
The server's `MissionScripting.lua` must leave `io` and `lfs` open, as the VEAF servers do.
Without them the campaign runs anyway, but does not save, and says so once.

**Reset**: F10 → Other → Campaign → **Reset the campaign (admin)**.
The campaign starts again from its declared state at the next load of the mission; a victory or a defeat does the same.

## Sleeping zones {#dormancy}

Away from the players, a zone has no unit in the world: its garrison is only a line of the save, losses included.
It comes back exactly as it was:

- **always**, when it is on the front (connected to a zone it does not hold) or targeted by a sortie;
- when an **enemy player's aircraft** comes within `wake_radius` (60 km), or within its air defence's reach plus `reach_wake_margin` (20 km) when that reach is longer;
- when an **enemy aircraft in the air**, AI included, comes within its air defence's reach plus `reach_wake_margin`: a long-range SAM therefore wakes much earlier than a zone with guns only;
- when an **enemy ground group** that is no garrison (a convoy, troops dropped, a spawn) comes within `ground_wake_radius` (10 km).

Only a zone's enemies wake it; vehicles placed in the editor and aircraft not yet activated wake nothing.
A defence's reach is its missiles', read from DCS while the zone is awake and kept in the save; a zone never seen awake has an assumed reach (75 km with a long-range SAM, 20 km otherwise).
It disappears when nobody has come near for `sleep_seconds` (600 s), except on the front.

At most `max_awake_zones` (12) zones of the rear are awake at once; the front and the targets of sorties do not count.
When the cap is reached, a zone wanted by a player takes the place of a zone only AI wants, or of a zone wanted by a player farther away; between zones wanted by AI, the first keeps its place, so that passing aircraft do not make zones appear and disappear in a loop.
Only one zone wakes per 10-second beat, so the whole front does not appear in one go.

## A front that moves on its own {#front}

- **Counter-attacks**: every `attack_seconds` (900 s), a side listed in `attacks` (red by default) sends an assault convoy against the weakest enemy zone it borders, `max_convoys` (2) on the road at most.
- **Resupply**: a delivery to a damaged friendly zone brings its first damaged group back to full strength.
  Deliveries are: a "Zone supplies" crate set down in the zone, CTLD 2 troops deployed in the zone (the spy team and the JTAC teams excepted), a supply helicopter landed in it.
- **AI helicopters**: every `supply_seconds` (600 s), a side listed in `supply` (red by default) sends a helicopter (`helicopter`, a Mi-8MT for red, a UH-1H for blue) to a neutral zone it borders, which it takes by landing there, or else to its most damaged zone, which it resupplies; `max_helicopters` (2) in the air at most, and one that has not landed after `helicopter_timeout` (1,200 s) is removed.

## Enemy air {#air}

- **CAP**: the enemy keeps one CAP up per `air.cap_per_players` (3) players of the [opposition level](scripts/veafQraManager.en.md#opposition-level), at least one, over its front zone nearest the players.
  Its patrol circle (40 km at most) stops 15 km short of our zones' air defence reach; when even a 5 km circle would be in their reach, it does not fly: it does not throw itself at our SAMs.
- **Strikes**: every `air.strike_seconds` (900 s), a CAS strike (on the zone with the most units) or a SEAD strike (on the one with the most air defence), in turn, on a zone bordering the enemy's territory.
- They **take off** from the nearest enemy airfield, hot on free stands (shelters first, open stands after; a large aircraft, bomber or transport, never in a shelter), or from the runway when there are not enough; no airfield, no sortie. So do the CAP, the BARCAP and the Hunter.
  Nothing takes off from an airfield within the measured reach of an enemy air defence (a Patriot would shoot the aircraft down while they climb): the sortie leaves from another airfield, or does not leave, and `dcs.log` says so (`[CAMPAIGN DECISION] nothing of red takes off from [Senaki]: it is under the air defence of [Kobuleti]`).
  `air.max_flights` (4) flights in the air at most per side.
- **Hunter**: a player on a kill streak (between 8 and 16 on the ground, or between 4 and 8 in the air, drawn once per life) then has a 10 % chance at every kill to have two enemy fighters scrambled at that player, whose side is told.

Aircraft are declared by type and loadout **by the name** the Mission Editor gives it; the tools check both and turn them into pylons, so the mission needs no aircraft template.

```yaml
dynamic:
  air:
    red:
      cap:  { type: MiG-29A, loadout: "R-73*2,R-60M*2,R-27R*2", count: 2 }
      cas:  { type: Su-25, loadout: "FAB-250*4,UB-13*2,R-60M*2,Fuel*2", count: 2 }
      sead: { type: MiG-27K, loadout: "Kh-25MPU*2,R-60M*2,Fuel", count: 2 }
    blue:
      cap:  { type: F-15C, loadout: "AIM-9*2,AIM-120*2,AIM-7*4,Fuel*3", count: 2 }
```

These are the defaults, made for the `MODERN` era: a campaign of another era declares its own.
An unknown loadout is refused by `campaign validate`, with the list of the type's loadouts.

## Credits and shop {#shop}

The players' coalition has an account, saved with the campaign: `economy.start_credits` (500) at the start.

| Gain | Setting | Default |
|---|---|---|
| a player destroys a ground unit | `economy.kill_ground` | 10 |
| a player shoots down an aircraft | `economy.kill_air` | 30 |
| a zone taken | `economy.capture` | 200 |
| a delivery to a friendly zone | `economy.delivery` | 100 |
| a [task](#tasks) done | `tasks.rewards` | 200 to 300 |

F10 → Other → Campaign → **Shop**: each item lists the zones it applies to.
A purchase refused (no target left, nothing in reach) costs nothing.

| Item | Effect | Price |
|---|---|---|
| JTAC drone | an MQ-9 over an enemy zone, lasing (code 1688); the zone is reconnoitred too | 300 |
| Illumination | illumination flares over a zone | 50 |
| Smoke on targets | red smoke on three units of an enemy zone | 50 |
| Intel | the composition of an enemy zone for an hour | 150 |
| Friendly CAP | a CAP of our side over one of our zones | 400 |
| BARCAP | a CAP of our side held in front of an enemy zone, out of its air defence's reach, to cover the helicopters and aircraft going to strike it | 400 |
| Capture helicopter | a helicopter that goes and takes a neutral zone | 250 |
| Resupply helicopter | a helicopter that goes and resupplies one of our damaged zones | 200 |
| Bomber raid | a [combined raid](#bombers) — BARCAP, SEAD, bomber — on an enemy zone, its buildings first | 1300 |
| Tanker | respawns the tanker `economy.tanker` names (an asset of the mission); absent without it | 300 |

The BARCAP holds on the axis between the enemy zone and our nearest airfield, at the first point out of the reach of **every** enemy air defence (not only the target zone's) plus 15 km, and guards a 15 km circle; when no point of the axis is out of reach, it holds over its airfield.
The reach is measured on the missiles the zone's units carry when it is awake; a sleeping zone is assumed to reach 75 km when its class has a long-range SAM, 20 km otherwise, and the message says so.

Prices change in `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `barcap`, `capture`, `resupply`, `bomber`, `tanker`, and `assault` for the assault order of F10 → Campaign → Assault, 300).
What the players buy is paid in credits, never from the [resources](#resources).

## The task board {#tasks}

F10 → Other → Campaign → **Tasks**: `tasks.count` (3) tasks at once, drawn from the situation and filled up every `tasks.refresh_seconds` (300 s), each marked on our side's map.

| Task | Done when | Reward |
|---|---|---|
| Attack the weakest enemy zone on the front | it is no longer the enemy's | 300 |
| Capture a neutral zone bordering ours | it is ours | 300 |
| Resupply our most damaged zone | it is back to full strength | 200 |
| Air superiority | `tasks.air_kills` (2) aircraft shot down | 200 |
| Intercept the enemy bombers on their way | the bomber is shot down; withdrawn if it goes home | 400 |

A task whose target went to the enemy is withdrawn, without reward.

## Intelligence {#intel}

An enemy zone's garrison is **unknown** to the players ("strength unknown" on the map) until it is reconnoitred, for `intel.seconds` (one hour):

- by an **overflight**: a player's aircraft within the zone's circle, less than `intel.overflight_altitude` (1,500 m) above the ground;
- by a **JTAC drone** or **intel** bought in the shop;
- by a **spy team**: the "Spy" CTLD 2 troop group deployed within `intel.spy_range` (5 km) of an enemy zone walks into it on its own, and reveals it on arrival.

A reconnoitred zone shows its strength on the map, and F10 → Other → Campaign → **Intel** gives its composition, air defence first.
`intel.hidden: false` shows every garrison to everyone.

## Factories and depots {#zone-kinds}

A zone is declared of a kind, `kind:`, besides its location:

| Kind | How it plays |
|---|---|
| none, on an airfield | an **airfield**: it is captured, its slots follow |
| none, on a point | an **outpost**: a garrison |
| `factory` | a **factory**: a few buildings and a small garrison; it makes its side's [resources](#resources) while its buildings stand |
| `depot` | a **depot**: it speeds the [supply network](#network) up and keeps a store of it |

```yaml
zones:
  - { name: Tkibuli, at: { lat: 42.350, lon: 42.998 }, size: outpost, side: red, kind: factory }
  - { name: Samtredia, at: { lat: 42.165, lon: 42.335 }, size: outpost, side: red, kind: depot }
```

A factory's buildings are drawn once, at the first start: `factory.buildings` (3) among `factory.types` (`Workshop A`, `Tech combine`, `Tech hangar A`), in a row 60 m apart on open ground in the zone.
They are statics: they stay in the world even while the zone sleeps.
The map counts those standing, "factory 2/3".
They are destroyed by bombs or by the [demolition team](#demolition); a factory is also captured like any other zone, and what stands of it then works for its new side.
A delivery (crate, troops, helicopter) to a factory whose garrison is whole rebuilds one building.

## The AI's resources {#resources}

Each side has **one stock of resource points** (`resources.start`, 500), saved with the campaign, and **everything the AI puts into play is paid from it** at the price of its units: the garrison of a captured zone, a reinforcement by the [network](#network), an assault convoy, a supply helicopter, a CAP, a strike, the Hunter, a [bomber raid](#bombers).
An empty stock sends nothing: a sortie leaves only if the stock stays above `resources.reserve` (100) once it is paid, so that the AI keeps what it needs to rebuild its zones.
A captured zone its side cannot pay gets a token garrison.
A [paid spawn](#paid-spawns) can take the stock below zero: the AI then pays for nothing, sortie nor reinforcement, until production brings it back up.

**Production** is added at every beat: a background production, `resources.background_per_hour` (30 points an hour), even with no factory, enough to just about hold a base; and each factory, `factory.per_hour` (120) times the share of its buildings standing.

**A unit's price** is read from the DCS unit database, by what the unit is:

| Unit | Points |
|---|---|
| infantry | 1 |
| unarmed vehicle | 2 |
| APC, IFV | 4 |
| tank | 6 |
| artillery | 5 |
| AAA, short-range air defence | 4 |
| short-range SAM | 8 |
| medium- or long-range SAM element | 15 |
| helicopter | 15 |
| aeroplane | 30 |
| bomber | 100 |
| anything else | 5 |

`resources.prices` changes a type's price: `{ "T-72B": 7 }`.
These are starting values, to be tuned on a server: one factory pays for about one counter-attack and one CAP an hour.

Credits stay the players': what they buy does not come out of the resources, and what survives of a purchase is added to them at the next load.
`resources.enabled: false` makes the AI free and unlimited, as before.

## The supply network {#network}

A side's factories feed its zones hop by hop, along the connections, and only through the side's zones: an enemy or neutral zone cuts the path, and the rest of the network is served by a detour, later.

- **A hop** from one zone to the next takes `network.hop_seconds` (600 s); **a hop that touches a depot** half of it: factory → base → base is two full hops, factory → depot → base one.
- **A depot** keeps a store of `network.depot_store` (4) deliveries, full while a factory reaches it: cut from its factories, it still feeds the zones around it until it runs dry.
- **A damaged zone**, of either side, orders a delivery, paid from the resources at the order; its first damaged group comes back whole after the zone's delay; `network.max_deliveries` (3) deliveries of a side on their way at once. A zone lost meanwhile receives nothing.
  Players who fly logistics go faster: a crate, troops or a helicopter reinforce at once, without waiting for the network or paying for it.
- **A zone cut off** from every factory and depot is still served, from the background production, after `network.isolated_seconds` (3,600 s).

F10 → Campaign → **Supply network** gives the players their stock, their production, and for each of their zones its delay or "cut off".

## Paid spawns {#paid-spawns}

In a persistent campaign, every VEAF spawn command a person drops as a marker — `_spawn`, `-armor`, `-cap`, a convoy, a crate, game masters included — is paid:

- **in credits** when it spawns units for the players' side;
- **from the resources** of the other side otherwise;
- at the price of **the units it made**, one by one, on the [resources' scale](#resources): a random armoured platoon costs what it drew, two tanks and an IFV are 6 + 6 + 4 = 16 points;
- the players' side pays `economy.credits_per_point` (6) credits a point: those 16 points are 96 credits;
- the price is known only once the units are drawn: the spawn therefore always goes through **whole** — multiplier included — and is paid its exact price, into **debt** if need be;
- a side at zero or in debt spawns nothing more: the command is refused before the spawn, with the balance, until the balance is above zero again; a gain pays the debt off first.

Smoke, flares, drawings, destroy, teleport and mission master stay free: they put no unit into play.
A batch alias (`-arty1`) is paid like its aliases: its battery is charged, though the password is checked only once.
What a script spawns (a combat zone, a command the interpreter reads from a name placed in the editor, the campaign's own sorties) is no person's action and is not paid here.

### Reserved commands {#reserved-commands}

Some commands would be cheating in a persistent campaign: it reserves them to the **admin** level (the one of the VEAF pilots file), whatever their level elsewhere.

| Reserved to admins | What they do |
|---|---|
| `-shell`, `-cesar`, `-flak`, `_spawn bomb` | explosions wherever one likes |
| `-destroy`, `_destroy` | destroy the units around the marker |
| `-tanker`, `-tankerhere`, `_teleport`, `_move … teleport` | teleport a group or the tanker |
| `-zonestart`, `-zonestop`, `-airstart`, `-airstop` | start or stop a combat zone or an air wave |
| `-send`, `-play`, `_radio` | broadcast a message or a sound to the whole server |
| `-light`, `_spawn flare` | free illumination, which the shop sells |

**`-cas` is turned off**: a CAS training zone makes no sense in a campaign.
Everything else keeps its module's level: smoke, signals, named points, beacons, drawings, the tanker's altitude, the commands of an artillery battery already placed.
The same rule holds for a command a pilot sends from afar.
A mission with security off (a test copy) lets everything through, `-cas` excepted.

## The demolition team {#demolition}

The CTLD 2 troop group **"Sappers"** (`demolition.troops`), dropped by the players' side, walks to the enemy factory whose buildings are within `demolition.range` (5 km) of where it was dropped.
Within 200 m of the buildings, it plants its charges on every one standing, says so, and walks back to its drop point.
The charges blow `demolition.fuse` (120 s) later, even if the team was killed meanwhile.
Each building destroyed is worth `economy.demolition` (50) credits, and the factory makes that much less.
With no enemy factory in range, the team says so and stays where it is.

## Weapon stocks {#warehouses}

The weapon stocks of each airfield of the campaign, read at every save, are set back as they were at the restart; an unlimited stock is left as it is.
The campaign makes no warehouse limited or unlimited: that is the Mission Editor's choice.

The players move stock from one field to another, in a helicopter or a transport aircraft:

1. on the ground at an airfield of the coalition, F10 → Campaign → Warehouse → **Load weapons** takes `warehouse.load` (10) of each weapon the warehouse holds (fewer when it has fewer);
2. on the ground at **another** airfield of the coalition, **Unload weapons** puts in exactly what is aboard, and earns `economy.warehouse_delivery` (50) credits, once per airfield in each flight;
3. **Cargo** tells what is aboard.

The cargo is lost with the aircraft, and with the server: it is not saved.
`warehouse.enabled: false` removes the menu and the restoring of the stocks.

## Strategic bombers {#bombers}

Every `bombers.seconds` (3,600 s), the enemy sends a **combined raid** at the players' zone with the most to hit: a factory first, else the zone with the most units, among those one of its airfields can reach.
Everything **takes off** from the enemy airfield nearest the target that is at least `bombers.min_distance` (80 km) from it, to leave the players time to intercept, like every campaign aircraft:

1. a **BARCAP** holds the axis, out of the reach of every enemy air defence (see the [BARCAP](#shop));
2. a **SEAD** flight, at the zone whose air defence covers the target (when one does), and the **bomber** meet at a hold point on the target's axis, the first point out of the defences' reach plus 15 km (over their airfield when there is none);
3. once both circle there, climbed to their altitude (within 1,000 m) and within 5 km of the point, the SEAD pushes to the target, and the bomber `bombers.package_delay` (30 s) behind it, on the same axis; when the SEAD was shot down on the way, the bomber pushes alone. Neither circles the hold point longer than 20 minutes.

The bomber flies at the SEAD's speed, to stay behind it, and drops its whole load in one pass, in a 1 km carpet on the target; it does not react to threats nor jettison its bombs: it presses on to the target.
With no defence to put out, no SEAD and no hold: the bomber flies straight to the target.

No escort by default: the BARCAP holds the approach, and the last leg is the players' interception window; `bombers.escort: true` gives it one back.
The package is paid whole, from the resources, or does not leave.
The players are told at once, and the [task board](#tasks) posts an intercept task.
One raid of a side in the air at a time.

The players buy the same package in the [shop](#shop): **Bomber raid**, on an enemy zone.

The bombers are declared like the other aircraft, role `bomber`:

```yaml
dynamic:
  air:
    red:
      bomber: { type: Tu-22M3, loadout: "FAB-250*33", count: 1 }
    blue:
      bomber: { type: B-1B, loadout: "Mk-82*84", count: 1 }
```

## Territory {#territory}

Each zone holds the part of the map nearer to it than to any other zone (its Voronoi cell), tinted on the F10 map in its side's colour, grey for a neutral zone; a dark line runs between two cells of different sides: the front, edged on each side with short slanted hatches in the side's colour, plain to see where the tint is faint.
The map is redrawn only when a zone changes hands.
`territory.margin` (70 km) extends the cells beyond the outer zones; `territory.hatch_spacing` (3,000 m) and `territory.hatch_length` (2,500 m) set the hatches' spacing and length; `territory.enabled: false` removes the tint.

## The debugging log {#debug-log}

While the campaign is being tuned, `dynamic.debug` (on by default) writes in `dcs.log` what the campaign does, in lines easy to search for:

| Tag | What it says |
|---|---|
| `[CAMPAIGN DECISION]` | every decision of the AI and its reason: a sortie sent, or not (no target, no airfield, no room left, nothing to pay with — with the price and the stock); a raid's package |
| `[CAMPAIGN FLIGHT]` | the fate of every campaign aircraft: a weapon released (with its distance to the aim and what it has left), a kill or a loss and by whom, a landing, a raid leaving its hold |
| `[CAMPAIGN AIRDEF]` | every `debug_status_seconds` (300 s): for each zone, its air defence units and the missiles they have left, empty launchers included |
| `[CAMPAIGN SUPPLY]` | the network's deliveries ordered, arrived, lost |
| `[CAMPAIGN ZONE]` | zones captured and turned neutral |
| `[CAMPAIGN STATUS]` | every `debug_status_seconds` (300 s): per side, zones, stock and production, deliveries on their way, flights up, raid out, and the players' credits |

`debug: false` turns it off, once the campaign is trusted.

## Checking a mission in game {#self-check}

F10 → Other → Campaign → **Self-check (admin)** prints one `OK` or `KO` line per mechanism: zones placed, save read and written, outcome, dormancy, captures, factories, territory, both sides' resources, network (deliveries and zones cut off), paid spawns, sappers, warehouses, helicopters, air, bombers, credits, tasks, intelligence.
A `KO` line is enough to know where to look.

## Every setting {#settings}

| `dynamic:` key | Default | What it sets |
|---|---|---|
| `save_seconds` | 60 | interval between two saves |
| `wake_radius` | 60000 | metres: an enemy player this close wakes a zone |
| `ground_wake_radius` | 10000 | metres: an enemy ground group that is no garrison, this close, wakes a zone; vehicles placed in the editor wake nothing |
| `reach_wake_margin` | 20000 | metres: an enemy aircraft this far beyond a zone's air defence reach wakes it |
| `sleep_seconds` | 600 | a zone with no player near it for this long goes back to sleep |
| `max_awake_zones` | 12 | zones of the rear awake at once (the front and the targets of sorties do not count) |
| `attacks` | `[red]` | the sides that counter-attack on their own |
| `attack_seconds` | 900 | interval between two counter-attacks of a side |
| `max_convoys` | 2 | a side's assault convoys on the road |
| `supply` | `[red]` | the sides whose AI helicopters capture and resupply |
| `supply_seconds` | 600 | interval between two helicopters of a side |
| `max_helicopters` | 2 | a side's supply helicopters in the air |
| `helicopter_timeout` | 1200 | a helicopter not landed after this long is removed |
| `helicopter` | `{red: Mi-8MT, blue: UH-1H}` | each side's helicopter type |
| `supply_crate` | `Zone supplies` | the name of the CTLD 2 crate that resupplies |
| `hunter` | `{enabled: true, ground_kills: 8, air_kills: 4, chance: 10}` | the Hunter |
| `air` | see [enemy air](#air) | `strike_seconds` (900), `max_flights` (4), `cap_per_players` (3), and each side's aircraft |
| `economy` | see [the shop](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker`, `credits_per_point` (6), `demolition` (50), `warehouse_delivery` (50) |
| `tasks` | see [the tasks](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`, `intercept`) |
| `intel` | see [intelligence](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |
| `resources` | see [the resources](#resources) | `enabled` (true), `start` (500), `background_per_hour` (30), `reserve` (100), `prices` |
| `factory` | see [the factories](#zone-kinds) | `buildings` (3), `per_hour` (120), `types` |
| `network` | see [the network](#network) | `hop_seconds` (600), `isolated_seconds` (3600), `depot_store` (4), `max_deliveries` (3) |
| `demolition` | see [demolition](#demolition) | `troops` (`Sappers`), `range` (5000), `fuse` (120) |
| `warehouse` | see [the stocks](#warehouses) | `enabled` (true), `load` (10) |
| `bombers` | see [the bombers](#bombers) | `enabled` (true), `seconds` (3600), `min_distance` (80000), `escort` (false), `package_delay` (30) |
| `debug` | see [the debugging log](#debug-log) | `true` while testing |
| `debug_status_seconds` | 300 | seconds between two status lines of the log |
| `territory` | see [territory](#territory) | `enabled` (true), `margin` (70000), `hatch_spacing` (3000), `hatch_length` (2500) |

The caps are conservative by default; they will be tuned from what the servers hold.

## Still to check in game {#to-verify}

These are written and tested outside DCS, not yet measured in game:

- an AI helicopter landing in a zone (DCS's known traps on a scripted landing are in [the DCS runtime traps](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/agents/dcs-runtime-traps.md));
- the CAS and SEAD strikes and their return;
- the spy team walking to its zone;
- a garrison disappearing and reappearing as a player passes;
- a factory's buildings placed on open ground, and raised again under the captor's flag;
- the bomber's `CarpetBombing` task, its "no reaction to threats" and "no jettison" options, and the combined raid's common hold point (flags `campaign raid <n> sead` / `bomber`);
- the sappers' charges, strong enough for a building, and the team out of their blast;
- an unlimited warehouse's stocks, which `getInventory` may report without counting them;
- the territory tint, made of triangles, on the F10 map.

See also the [`veafCampaign` module reference](scripts/veafCampaign.en.md).
