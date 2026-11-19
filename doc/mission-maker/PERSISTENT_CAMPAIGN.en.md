# Persistent campaign

> One mission that runs on a server for weeks, in the spirit of Foothold: zones that change hands, a front that moves on its own, enemy air, credits to spend, and a save that resumes where the server stopped.
> Built on the VEAF tools and scripts alone, without Moose.
> It is the other mode of the [multi-mission campaign](CAMPAIGN.en.md): same `campaign.yaml`, same zones, same garrisons, but the campaign moves during the flight rather than between two missions.

## What the players see {#players}

- **The F10 map** shows each zone as a circle in its owner's colour, with its name, the number of its [waypoint](#waypoints) and its garrison's state, and the connections between zones.
  An enemy zone reads "strength unknown" until it has been [reconnoitred](#intel).
- **A zone never changes hands directly**: when its garrison is destroyed it turns **neutral** (grey).
  A neutral zone is taken by holding the ground: ground units of a single side staying there for `capture_seconds` (120 s by default) — CTLD 2 troops or crate, a convoy, a `_spawn` group, a Combined Arms vehicle, a **landed** helicopter.
  Landed helicopters alone take `helicopter_capture_seconds` (600 s), and leave a token garrison: what a helicopter carries, `helicopter_garrison` soldiers (6) and no vehicle, whatever the zone's size class.
  The new garrison appears at once.
- **A pilot on the ground after an ejection is nobody's enemy**: the survivor the CSAR module puts down neither holds nor contests a zone, wakes no zone and stops no convoy, in every VEAF script.
- **Slots follow the bases**: an airfield taken goes to the side that took it, with its dynamic slots.
  Every airfield of the campaign has its slots ready from the build, even those the players' side does not hold yet (see [Building the mission](#build)).
  The campaign alone decides who owns an airfield: DCS's own capture of an airbase by the units around it is turned off on every airfield of the map.
- **The front moves on its own**: the enemy [counter-attacks](#front), reinforces its zones by helicopter, and sends CAP, strikes and [bombers](#bombers).
- **The enemy pays for what it sends** with the [resources](#resources) its factories make: destroying its [factories](#zone-kinds) or cutting its [supply network](#network) grounds its CAP in the end.
- **The map is tinted** by side, each zone holding the [territory](#territory) nearest to it, and the front reads between the two colours.
- **Every announcement says who speaks**: "Blue command:" (or red) for what a side does or suffers, "Intelligence:" for what is learnt of the enemy — a convoy or a helicopter leaving, a raid inbound.
- **The F10 → Other → VEAF → Campaign menu** gives the situation, the credits, the tasks, the intelligence and the shop; the "(admin)" commands come last.
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

**Slots on every airfield of the campaign.** `campaign next` writes, in the mission's `src\warehouses.yaml`, the players' side's `airports:` list with **every airfield of the campaign**, whatever its side at the start.
Without that list, the build opens dynamic slots only on the airfields the side holds when the mission is built: an airfield captured in flight had no slot to offer (Minakh, 2026-11-19).
An airfield already in the list keeps its settings; a base the mission gives the side outside the campaign's zones (a rear base set in the template) is added by its id, to keep its slots; a side the file does not declare stays without slots.
`campaign apply` has no use here: there is no "between two missions".

**Weather and time come from the server.** A persistent campaign runs for weeks: `campaign next` fixes neither date, start time nor weather, and the mission's name carries no `_NoMizedit` (`Campaign_<campaign>_Mission_01_<title>`), so the server's MizEdit preset (with RealWeather) sets them at each load. A [multi-mission campaign](CAMPAIGN.en.md#squadron-settings) keeps its fixed conditions and its `_NoMizedit`.

### The mission's file name {#mission-file}

The DCS server browser shows the file name, and `Campaign_<campaign>_Mission_01_<title>_<YYYYMMDD>.miz` is too long to read there.
The date also changes the name at each redeploy, and the server's configuration must then be edited.
`mission_file` gives the file a fixed name, with no date:

```yaml
campaign:
  name: Northern Syria
  mode: persistent
  mission_file: Campagne_Oronte     # the build writes Campagne_Oronte.miz
```

`campaign next` writes this name into `mission.name` and adds `mission.date_suffix: false` to `mission.yaml`: the build then writes `Campagne_Oronte.miz` in the mission folder, and a redeploy just replaces the file.
The name is made of ASCII letters, digits, dashes and underscores, with no extension or `.miz`; `campaign validate` refuses any other name.
Without the key, the name stays `Campaign_<campaign>_Mission_01_<title>`, dated by the build.
The key is refused on a [multi-mission campaign](CAMPAIGN.en.md#squadron-settings): each of its missions needs `_NoMizedit` in its file name, and a file of its own.

The briefings are those of a campaign with no mission of the day: the [theatre dossier and the kneeboard](#theatre-dossier) replace the campaign briefing and the mission briefing.

`campaign next` also adds to the mission's `ctld-config.yaml` what the players carry for the campaign: the **"Zone supplies"** crate (one per side), the **"Spy"** troop group (one man) and the **"Sappers"** group (two men, the [demolition team](#demolition)).
It writes the players' [waypoints](#waypoints), one per zone, and, when it creates the mission folder, its [radio plan](#radio-plan) and its [DCS briefing](#theatre-dossier) from `briefing.yaml` — so a mission folder created afresh keeps it; write it there, not in the mission alone.
It also enforces the "fog of war" F10 view (`mission.forced_options.f10_view: fog_of_war`): a pilot sees only the enemies their side has detected, and a garrison's strength is learned by [reconnaissance](#intel). A view already chosen in `mission.yaml` is kept.

**No interpreter command in a persistent campaign.**
A unit named `#veafInterpreter["…"]` in the Mission Editor spawns its units afresh at every start of the mission: in a persistent campaign, they come back whole after each server restart, their losses forgotten, paid by nobody.
What the campaign must hold is declared in `campaign.yaml`, as a zone with its garrison (an explicit `garrison:` list when the composition matters): the zone is saved with its losses, and the [network](#network) rebuilds it at its side's expense.
`campaign next` reports the interpreter commands it finds in the mission.

**What `campaign validate` and `campaign next` warn about**, each a defect of the first evening flown:

- a zone at coordinates within 4 km of an airfield, with no `kind:`: put it on the airfield (`at: { airfield: … }`), or DCS and the campaign each capture their own object;
- no AWACS nor tanker in `dynamic.support.assets`, no `dynamic.economy.tanker`, or one of them that is no group of the template mission: the players fly without, and the shop has no tanker;
- no boom tanker (KC-135, KC-10A) or no basket tanker (KC-135MPRS, KC-130, S-3B, IL-78M) among `dynamic.support.assets`: the F-16 and the A-10, or the F/A-18 and the AV-8B, cannot refuel;
- a channel of the template's `src/presets.yaml` named after an airfield of another theatre: write the campaign's frequency plan for its theatre;
- more [long-range SAMs](#long-range-sams) than allowed, or too close, is an error.

### A waypoint per zone {#waypoints}

`campaign next` writes in `src/waypoints.yaml` a waypoint per zone of the campaign, at its centre, on the ground, for the players' planes and helicopters, the most strategic first: the zones of the front (connected to a zone of another owner), then the airfields, the factories, the depots and the rest, nearest the players' zones first.
A module that holds fewer steerpoints than there are zones keeps the first ones.
Each zone keeps its number, the one after the departure point: the F10 label, the situation, the shop, the intelligence and every announcement name it "Taftanaz (WP 7)".
The order is the one of the campaign's state when `campaign next` runs; the build adds BULLSEYE after them.
A `waypoints.yaml` edited by hand is left alone, as for a [multi-mission campaign](CAMPAIGN.en.md), and the numbers the players read are the ones it holds: a zone it leaves out shows none.

### The radio plan {#radio-plan}

When it creates the mission folder, `campaign next` writes the players' radio plan in `src/presets.yaml`; edited afterwards, it is the mission maker's.

| Radio | Channels |
|---|---|
| VHF, the airfields' radio | 1 **Home Base**, which each pilot sets to the field taken off from; then the players' side's airfields, with the frequencies DCS gives them on this theatre; then the VEAF flights, on their VHF frequency: a flight tuned to a tanker's UHF still talks on the VHF |
| UHF | the AWACS, then the tankers of `dynamic.support.assets` and `economy.tanker`, on their group's frequency, each named with how it refuels ("Tanker Texaco (boom)", "Tanker Arco (basket)"); **Air-Sol**, the common air-to-ground frequency (305.0); then the VEAF flights, Archer first |

A channel needs a frequency for the build to keep it on the radio and the kneeboard: Home Base carries a placeholder no airfield of DCS uses (VHF 118.025, UHF 230.025), which the pilot overwrites.
The AWACS and the tankers must therefore be in the template before the first `campaign next`.

### The theatre dossier and the kneeboard {#theatre-dossier}

A persistent campaign has no mission of the day: instead of the [campaign briefing](CAMPAIGN.en.md#briefing-deck) and the [mission briefing](CAMPAIGN.en.md#mission-briefing), `campaign next` and `campaign briefing` write the **theatre dossier** into `missions\mission-01\`, `<operation>_dossier-de-theatre.pptx`, with its two maps (`carte-du-reseau.png`, `carte-des-defenses.png`).
It is a dated picture of the situation ("État au 17/11/2026"), not an operation order: no objectives, no ATO, no weather.
The same dossier is also written as a PDF beside it, `<operation>_dossier-de-theatre.pdf`, readable without PowerPoint ([as every briefing is](CAMPAIGN.en.md#briefing-deck)).

| Page | What it says |
|---|---|
| Cover | the operation, the theatre, the date of the picture |
| Strategic situation | `briefing.yaml`: political, economic, enemy course of action |
| Network map | each zone in its side's colour, a symbol per kind (square airfield, circle outpost, triangle factory, diamond depot), its [waypoint](#waypoints) number, the connections, the territory tinted by side and the front with its short hatches on each side, as on the F10 map |
| The enemy network | which factory feeds which zones, what each depot speeds up, the zones already cut off, and the **critical nodes**: the enemy zones whose capture cuts other zones off from their factory |
| Known air defences | the [long-range SAMs](#long-range-sams) with their reach drawn as a circle, and what intelligence knows of them ("probable" until a reconnaissance confirms it); ours too |
| Axes of effort | `axes:` from `briefing.yaml`, given as indicative: the situation moves, adapt |
| Our means | our zones, our airfields, the AWACS and the tankers |
| Radio plan | the UHF and VHF channels of the [radio plan](#radio-plan), read from `src/presets.yaml` |
| Player's guide | the F10 Campaign menu, the rule for taking a zone, the [shop](#shop) prices |
| Rules of engagement | `briefing.yaml` |

The **axes of effort** are written in `briefing.yaml`, under an `axes:` key, each with a title and a text:

```yaml
axes:
  - title: Take Menagh and Afrin
    text: Drop troops or supply crates in both neutral towns and hold them for two minutes.
  - title: Cut the red network
    text: The critical nodes of the theatre dossier cut zones off from their factory; taking them weakens everything those zones hold.
```

A `briefing.yaml` written before `axes:` still works: without that key, the tasks of `missions: 1:` stand in for it.

**The kneeboard.** `campaign next` also writes four kinds of pages into the mission's `src/mission/KNEEBOARD/IMAGES`, which the build puts into the `.miz` and every aircraft shows:

1. the network map, in the kneeboard's format;
2. the zone table: waypoint, name and kind, coordinates (DDM and MGRS), elevation in feet, the airfield's VHF/UHF frequencies;
3. the radio plan;
4. a cheat sheet: the F10 Campaign menu, the capture rule, the shop prices.

No weather page (the server makes the weather) and no objectives.
These pages are named `NN-briefing-campaign-….jpg`: `campaign next` replaces them at every run and leaves the folder's other pages alone.
They show the state at the time of `campaign next`, not the server's save: run `campaign next` and the build again to refresh them.

**The DCS briefing** comes down to the situation (the operation, the mission statement, the strategic situation), the axes of effort, and a pointer to the kneeboard for the map, the coordinates, the frequencies and the cheat sheet.

### Long-range SAMs {#long-range-sams}

A long-range SAM is a zone's own: `long_range_sam: true` on the zone.
Two SA-5 17 nautical miles apart put a whole front under 240 km of missile reach on the first evening flown; `campaign validate` therefore refuses more than `long_range_sams.per_side` (2) per side, and two of a side closer than `long_range_sams.min_spacing` (120 km).
Keep them for the key points of the network: a large base, a factory, a depot.

```yaml
long_range_sams: { per_side: 2, min_spacing: 120000 }
zones:
  - { name: Aleppo, at: { airfield: Aleppo }, size: airfield, side: red, long_range_sam: true }
```

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

**Reset**: F10 → Other → VEAF → Campaign → **Reset the campaign (admin)**.
The campaign starts again from its declared state at the next load of the mission; a victory or a defeat does the same.

### The block for the web map {#sitac}

Every save adds a `sitac` block to the same file, made for a map read outside DCS: VEAF's web sitac ([foothold-sitac](https://github.com/VEAF/foothold-sitac)) reads it to draw the campaign as it draws Foothold.
The mission never reads this block back: it is computed again at every save.

```lua
sitac = {
  theatre = "Syria", campaign = "Bouclier de l'Oronte", updated = 5432.1, -- simulation time, in seconds
  zones = {
    { name = "Minakh", waypoint = 3, kind = "airfield", lat = 36.52, lon = 37.04, owner = "blue",
      garrison = { alive = 9, total = 12 }, awake = true },
    { name = "Tal Rifaat", kind = "outpost", lat = 36.47, lon = 37.10, owner = "neutral",
      capture = { side = "blue", seconds = 42 }, awake = false },
    { name = "Kafr Naya", kind = "factory", lat = 36.41, lon = 37.02, owner = "red",
      garrison = { alive = 5, total = 6 }, structures = { standing = 2, total = 3 }, awake = false },
  },
  connections = { { "Minakh", "Tal Rifaat" }, { "Tal Rifaat", "Kafr Naya" } },
  convoys = { { side = "blue", from = "Minakh", to = "Tal Rifaat", units = 4 } },
  sides = { blue = { credits = 1915, resources = 600 }, red = { resources = 250 } },
  players = {
    { coalition = "blue", unitType = "A-10C_2", playerName = "Zip", latitude = 36.50, longitude = 37.01, altitude = 3048 },
  },
  playerStats = {
    Zip = { Points = 420, Air = 1, SAM = 2, ["Ground Units"] = 7, Infantry = 3, Helo = 0, Structure = 1, Deaths = 1,
      ["Warehouse delivery"] = 2 },
  },
  ejectedPilots = { { playerName = "Paluche", latitude = 36.45, longitude = 37.08, altitude = 412, lostCredits = 15 } },
  missions = {
    { title = "Capture Tal Rifaat (300 cr.)", description = "", isRunning = true, isEscortMission = false,
      kind = "capture", zone = "Tal Rifaat", reward = 300 },
    { title = "Air superiority (200 cr.)", description = "1/3", isRunning = true, isEscortMission = false,
      kind = "air", reward = 200 },
  },
  support = {
    { name = "Arco", kind = "tanker_boom", side = "blue", latitude = 36.20, longitude = 36.60, altitude = 7620,
      frequency = 252.5, tacan = "51Y", alive = true },
    { name = "Overlord", alive = false },
  },
}
```

- `zones` follows the order of `campaign.yaml`; `kind` is `airfield`, `outpost`, `factory` or `depot`; `lat`/`lon` are the zone's centre, in decimal degrees.
- `garrison` gives only the **counts** of units alive and in total, never their type: the composition stays hidden until the zone is reconnoitred, and the map is public. A neutral zone has none.
- `capture` is there only during a capture; `structures`, only for a factory or a depot that has buildings.
- `awake` is false for a sleeping zone.
- `convoys` keeps only the assault convoys still on the road; `units` counts their vehicles alive.
- `sides` gives the players' side's credits and each side's resources, when they are counted.

The next five lists use the **field names of Foothold's save**, so that the sitac shows them as it shows Foothold's.
They are as fresh as the save: one every `state_write_seconds` (60 s) of simulation, and none while the server is paused.

- `players`: each player in a slot, both sides, with his side, aircraft and position (`altitude` in metres).
- `playerStats`: the ranking, by pilot name. `Points` is the total of the credits he earned; `Air`, `Helo`, `SAM` (all the ground-based air defence), `Ground Units`, `Infantry` and `Structure` count what he destroyed; `Deaths` his deaths, `Warehouse delivery` his weapon deliveries.
  These figures are kept in the save and start from zero with the campaign. A capture is credited to no pilot: it does not show in the ranking.
- `ejectedPilots`: the players' side's pilots on the ground the CSAR waits to rescue, AI included; `lostCredits` gives the credits he carried, lost at the ejection (a rescue does not give them back). A pilot picked up leaves the list.
- `missions`: the [task board](#tasks), with the title the F10 menu gives; `description` gives an air superiority task's progress; `kind`, `zone` and `reward` on top of Foothold's.
- `support`: the players' side's [AWACS and tankers](#support), where they fly, with their kind (`awacs`, `tanker_boom`, `tanker_basket`, `tanker_both`, `tanker`), their frequency in MHz and their TACAN; one destroyed has only its name and `alive = false`.

The enemy's units, zone by zone, are never there: that is the [intelligence](#intel) rule.

## Sleeping zones {#dormancy}

Away from the players, a zone has no unit in the world: its garrison is only a line of the save, losses included.
It comes back exactly as it was:

- **always**, when it is within `front_depth` (40 km) of the front line drawn on the map, or connected to a zone of another side, or targeted by a sortie: an enemy going round finds someone there;
- when an **enemy player's aircraft** comes within `wake_radius` (60 km), or within its air defence's reach plus `reach_wake_margin` (20 km) when that reach is longer;
- when an **enemy aircraft in the air**, AI included, comes within its air defence's reach plus `reach_wake_margin`: a long-range SAM therefore wakes much earlier than a zone with guns only;
- when an **enemy ground group** that is no garrison (a convoy, troops dropped, a spawn) comes within `ground_wake_radius` (10 km).

Only a zone's enemies wake it; vehicles placed in the editor and aircraft not yet activated wake nothing.
A defence's reach is its missiles', read from DCS while the zone is awake and kept in the save; a zone never seen awake has an assumed reach (75 km with a long-range SAM, 20 km otherwise).
It disappears when nobody has come near for `sleep_seconds` (600 s), except near the front.
Awake, a zone keeps its garrison `sleep_margin` (20 km) farther than it wakes: a player hovering around 60 km does not make it disappear and appear again.
Asleep for less than `wake_rest_seconds` (300 s), it wakes for the front, a sortie or a player only, not for an AI aircraft passing by.

At most `max_awake_zones` (12) zones of the rear are awake at once; the front and the targets of sorties do not count.
When the cap is reached, a zone wanted by a player takes the place of a zone only AI wants, or of a zone wanted by a player farther away; between zones wanted by AI, the first keeps its place, so that passing aircraft do not make zones appear and disappear in a loop.
Only one zone wakes per 10-second beat, so the whole front does not appear in one go.
Its garrison comes group by group, about `wake_units_per_beat` (10) units per beat, its long-range battery last, a group never split (a launcher apart from its radar does not fire): Hama's 42 units in one go froze the server; the garrison of a zone just taken comes the same way.

## A front that moves on its own {#front}

- **Counter-attacks**: every `attack_seconds` (900 s), a side listed in `attacks` (red by default) sends an assault convoy against the weakest enemy zone it borders, `max_convoys` (2) on the road at most.
  Only those sides send convoys on their own toward a neutral zone too; the players' side buys theirs (F10 → Other → VEAF → Campaign → Assaults), and no automatic convoy leaves for a zone a convoy of the same side already drives to.
- **An assault convoy drives at `assault_speed` (40 km/h)**, without dispersing under fire; at its departure, `dcs.log` gives the length of its road, the time it needs and when it will be retired, then every `convoy_report_seconds` (300 s) its distance to its target and whether it moves on, stands still or turns back.
  Under aircraft it drives on; if it falls back before a stronger ground force for `fall_back_seconds` (120 s) without taking its road again, its assault is over: it is retired.
- **A convoy that will not arrive frees its place**: once its target is its side's (a helicopter took it first), when it falls back, or after the time its road needs (half as long again as expected, `convoy_timeout`, 2,700 s, at least), it is taken off the map and the price of its survivors goes back to its side; on 2026-11-17, at 20 km/h on roads of 40 to 60 km, the 45 minutes retired every convoy before it arrived.
  **Never in front of the players**: a convoy to retire stays in play while a player is within `wake_radius` of it, or it was hit in the last `retire_quiet_seconds` (300 s); its losses count, and only its survivors when it leaves are given back. On 2026-11-19, Aleppo's assault on Menagh vanished under a player's fire.
- **The other side is told at once** of a convoy leaving, and sees its axis on the map.
- **Resupply**: a delivery to a damaged friendly zone brings its first damaged group back to full strength.
  Deliveries are: a "Zone supplies" crate set down in the zone, CTLD 2 troops deployed in the zone (the spy team and the JTAC teams excepted), a supply helicopter landed in it.
- **AI helicopters**: every `supply_seconds` (600 s), a side listed in `supply` (red by default) sends a helicopter (`helicopter`, a Mi-8MT for red, a UH-1H for blue) to a neutral zone it borders, which it takes by landing there, or else to its most damaged zone, which it resupplies; `max_helicopters` (2) in the air at most, and one that has not landed after `helicopter_timeout` (1,200 s) is removed.
  The other side is told when it leaves, to intercept it.
  One that lands again away from its zone has failed at once, and `dcs.log` says where it landed.
  In an airfield zone it lands on the field; in any other zone (a town, a point), on the clear spot nearest the centre, within 60 % of its radius: sent to Afrin's centre, four Mi-8 turned back at once.
- **The AI remembers what fails**: after `route_failures` (2) helicopters or assault convoys of a side failed in a row to the same zone, that side sends nothing of the kind there for `route_failure_seconds` (3,600 s); a success clears the count.

## Enemy air {#air}

- **CAP**: the enemy keeps one CAP up per `air.cap_per_players` (3) players of the [opposition level](scripts/veafQraManager.en.md#opposition-level), over its front zone nearest our fighters.
  That level follows the **fighters** in the air: the players carrying a radar-guided air-to-air missile (the `air_to_air` follow, set by default when the mission follows nothing else). Helicopters and attack airplanes (A-10, Su-25, AV-8B…) do not count: when no fighter flies, no CAP takes off.
  Its patrol circle (40 km at most) stops 15 km short of our zones' air defence reach; when even a 5 km circle would be in their reach, it takes the next front zone, and does not fly when none suits: it does not throw itself at our SAMs.
  It engages our combat airplanes; a helicopter or an attack airplane it detects is engaged only on a draw of `air.cap_helicopter_chance` (25 %), made once per aircraft, as Foothold's `InvisibleA10` option.
- **Strikes**: every `air.strike_seconds` (900 s), a CAS strike (on the zone with the most units) or a SEAD strike (on the one with the most air defence), in turn, on a zone bordering the enemy's territory.
  A CAS strike leaves out a zone under a measured air defence of 15 km or more (a Hawk, an SA-6), the zone's own or a neighbour's: that is the SEAD's job.
- They **take off** from the nearest enemy airfield, hot on free stands (shelters first, open stands after; a large aircraft, bomber or transport, never in a shelter), or from the runway when there are not enough; no airfield, no sortie. So do the CAP, the BARCAP and the Hunter.
  Nothing takes off from an airfield within `takeoff_threat_range` (40 km) of an enemy air defence whose reach was measured (a Patriot would shoot the aircraft down while they climb); the reach DCS gives is the missile's against a high target, much longer than the range at which the SAM sees an aircraft taking off, hence this cap, an estimation to tune.
  No aeroplane of the AI leaves a field whose longest runway is shorter than `min_runway_length` (1,500 m), and one flight at a time leaves a field's runway: on 2026-11-17 fifteen aircraft sent from Taftanaz piled up on one spot of its strip and never took off.
  A flight still on the ground `takeoff_timeout` (600 s) after its spawn is taken away, its price back in the stock, and its field sends no aeroplane for `grounded_seconds` (3,600 s).
  A **SEAD** flight takes off all the same: putting that defence out is its job, and what it destroys frees the field for the strikes.
  Otherwise the sortie leaves from another airfield, or does not leave, and `dcs.log` says so (`[CAMPAIGN DECISION] nothing of red takes off from [Senaki]: it is under the air defence of [Kobuleti]`).
  `air.max_flights` (4) flights in the air at most per side.
- **Hunter**: a player flying a fighter on a kill streak (between 8 and 16 on the ground, or between 4 and 8 in the air, drawn once per life) then has a 10 % chance at every kill to have two enemy fighters scrambled at that player, whose side is told.

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

A player's kill pays in two parts: `economy.landing_share` (50 %) of it is held until the pilot lands at a friendly airfield, FARP or carrier, and lost on an ejection, a death or a crash; the rest is earned at once.
Both parts go to the coalition's account.
The other gains, which no single pilot carries, are paid whole.

F10 → Other → VEAF → Campaign → **Shop**: each item lists the zones it applies to.
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
| Escort for my group | two fighters for the buyer's group, starting in the air over our nearest airfield: an airplane gets the DCS escort task; a helicopter, too slow for fighters, a 15 km CAP over it, moved when it has gone 8 km. In each pilot's menu | 300 |
| Tanker | one item per tanker `economy.tanker` names — one name, or a list: the boom and the basket —, which it respawns (an asset of the mission), then [places](#support) out of reach again; absent without one | 300 |

The BARCAP holds on the axis between the enemy zone and our nearest airfield, at the first point out of the reach of **every** enemy air defence (not only the target zone's) plus 15 km, and guards a 15 km circle; when no point of the axis is out of reach, it holds over its airfield.
The reach is measured on the missiles the zone's units carry when it is awake; a sleeping zone is assumed to reach 75 km when it holds a [long-range SAM](#long-range-sams), 20 km otherwise, and the message says so.

Prices change in `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `barcap`, `capture`, `resupply`, `bomber`, `escort`, `tanker`, and `assault` for the assault order of F10 → Other → VEAF → Campaign → Assault, 300).
What the players buy is paid in credits, never from the [resources](#resources).

## The task board {#tasks}

F10 → Other → VEAF → Campaign → **Tasks**: `tasks.count` (3) tasks at once, drawn from the situation and filled up every `tasks.refresh_seconds` (300 s), each marked on our side's map.

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

A reconnoitred zone shows its strength on the map, and F10 → Other → VEAF → Campaign → **Intel** gives its composition, air defence first.
`intel.hidden: false` shows every garrison to everyone.

## Factories and depots {#zone-kinds}

A zone is declared of a kind, `kind:`, besides its location:

| Kind | How it plays |
|---|---|
| none, on an airfield | an **airfield**: it is captured, its slots follow |
| none, on a point | an **outpost**: a garrison |
| `factory` | a **factory**: a few buildings and a small garrison; it makes its side's [resources](#resources) while its buildings stand |
| `depot` | a **depot**: a few buildings; it speeds the [supply network](#network) up and keeps a store of it while its buildings stand |

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

A depot has buildings too, drawn the same way: `network.depot_buildings` (3) among `network.depot_types` (`Warehouse`, `Fuel tank`, `Tank`); the map says "depot 2/3".
While one of its buildings stands it is a depot: it keeps its store, shortens the hops and may supply itself.
**Its buildings all destroyed**, its store burns with them and it is only an ordinary node of the network: supplied like any other zone, from a factory or another depot.
It is a depot again only after `network.depot_rebuild_seconds` (2,700 s), all its buildings rebuilt at once for the side holding the zone: time enough to destroy its garrison and take it.
No delivery rebuilds a depot's building.
To take a depot: destroy its buildings first, or it repairs its garrison itself; then its garrison, before the rebuild.

## The AI's resources {#resources}

Each side has **one stock of resource points** (`resources.start`, 1,000), saved with the campaign, and **everything the AI puts into play is paid from it** at the price of its units: the garrison of a captured zone, a reinforcement by the [network](#network), an assault convoy, a supply helicopter, a CAP, a strike, the Hunter, a [bomber raid](#bombers).
An empty stock sends nothing: a sortie leaves only if the stock stays above `resources.reserve` (100) once it is paid, so that the AI keeps what it needs to rebuild its zones.
A captured zone its side cannot pay gets a token garrison, and so does a zone taken by helicopters alone.
A [paid spawn](#paid-spawns) can take the stock below zero: the AI then pays for nothing, sortie nor reinforcement, until production brings it back up.

**Production** is added at every beat: a background production, `resources.background_per_hour` (60 points an hour), even with no factory, enough to just about hold a base; and each factory, `factory.per_hour` (180) times the share of its buildings standing.
These three values were raised after the first evening flown: with 500, 30 and 120, red had nothing left after 1 h 20, no CAP, strike nor raid.

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
- **A depot** keeps a store of `network.depot_store` (4) deliveries, full while a factory reaches it: cut from its factories, it still feeds the zones around it until it runs dry. Its [buildings](#zone-kinds) destroyed, it keeps nothing and shortens no hop.
- **A damaged zone**, of either side, orders a delivery, paid from the resources at the order at the price of the units it is missing; `network.max_deliveries` (3) deliveries of a side on their way at once.
  After the zone's delay, the delivery brings back the dead units of its first damaged group, **cheapest first and up to what it paid**: a unit killed since the order stays dead.
  The units brought back appear in their places; the living ones do not move.
  **A zone under fire** — a unit lost less than `network.under_fire_seconds` (600 s) ago — is not reinforced: the delivery waits.
  A zone lost meanwhile receives nothing; a delivery with nothing left to repair, or what it did not spend, goes back to the stock.
  Players who fly logistics go faster: a crate, troops or a helicopter reinforce at once, without waiting for the network or paying for it.
- **A zone cut off** from every factory and depot is still served, from the background production, after `network.isolated_seconds` (3,600 s).

F10 → Other → VEAF → Campaign → **Supply network** gives the players their stock, their production, and for each of their zones its delay or "cut off".

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

1. on the ground at an airfield of the coalition, F10 → Other → VEAF → Campaign → Warehouse → **Load weapons** takes `warehouse.load` (10) of each weapon the warehouse holds (fewer when it has fewer);
2. on the ground at **another** airfield of the coalition, **Unload weapons** puts in exactly what is aboard, and earns `economy.warehouse_delivery` (50) credits, once per airfield in each flight;
3. **Cargo** tells what is aboard.

The cargo is lost with the aircraft, and with the server: it is not saved.
`warehouse.enabled: false` removes the menu and the restoring of the stocks.

## Strategic bombers {#bombers}

Every `bombers.seconds` (3,600 s), the enemy sends a **combined raid** at the players' zone with the most to hit: a factory first, else the zone with the most units, among those one of its airfields can reach.
Everything **takes off** from the enemy airfield nearest the target that is at least `bombers.min_distance` (80 km) from it, to leave the players time to intercept, like every campaign aircraft:

1. a **BARCAP** holds the axis, out of the reach of every enemy air defence (see the [BARCAP](#shop));
2. a **SEAD** flight, at the zone whose air defence covers the target (when one does), and the **bomber** meet at a hold point on the target's axis, the first point out of the defences' reach plus 15 km (over their airfield when there is none);
3. once both circle there, climbed to their altitude (within 1,000 m) and within 15 km of the point (a holding circle's radius), the SEAD pushes to the target, and the bomber `bombers.package_delay` (30 s) behind it, on the same axis; when the SEAD was shot down on the way, the bomber pushes alone. Neither circles the hold point longer than 20 minutes.

The bomber flies at the SEAD's speed, to stay behind it, and drops its whole load in one pass, in a 100 m carpet on the target; it does not react to threats nor jettison its bombs: it presses on to the target.
After the target, it flies 20 km back along the axis it came in on, which its SEAD cleared, before it turns home.
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
      bomber: { type: Tu-22M3, loadout: "FAB-500*33", count: 1 }
    blue:
      bomber: { type: B-1B, loadout: "Mk-84*24", count: 1 }
```

## AWACS and tankers {#support}

The AWACS and tankers named in `support.assets` (assets of the mission, with an orbit in the Mission Editor) are held out of the enemy's air defence by the [`veafSupport` module](scripts/veafSupport.en.md), which `campaign next` turns on in `mission.yaml` with these settings; the campaign hands it the reach of its zones, asleep or awake, and its front:

- on the line from their Mission Editor orbit to the enemy zone nearest it, at the first point out of the reach of **every** enemy air defence plus `support.margin` (30 km), never ahead of their side's own zone nearest that enemy;
- out at once, with `support.retreat_margin` (50 km), when a reach comes over its orbit; closer only after 30 minutes of calm and for a step of 30 km at least (`support.advance_seconds`, `support.min_advance`), so a SAM that wakes and sleeps does not make it shuttle; its leg (`support.leg`, 30 nm) laid across the axis;
- its F10 marks (leg and label, for its side) redrawn at each move;
- each move told to its side: the new orbit in bearing and range from the bullseye, frequency unchanged.

A persistent campaign holds **two tankers**, a boom (a KC-135) and a basket (a KC-135MPRS or a KC-130 for blue), each placed out of reach like the AWACS, and both sold in the shop.

```yaml
dynamic:
  support:
    assets: [ "AWACS Magic", "Tanker Texaco", "Tanker Arco" ]
  economy:
    tanker: [ "Tanker Texaco", "Tanker Arco" ]
```

The reach is the one [the BARCAP](#shop) uses: measured on the missiles while a zone is awake, assumed for a zone never seen awake.

## Territory {#territory}

Each zone holds the part of the map nearer to it than to any other zone (its Voronoi cell), tinted on the F10 map in its side's colour, grey for a neutral zone; a dark line runs between two cells of different sides: the front, edged on each side with short slanted hatches in the side's colour, plain to see where the tint is faint.
The map is redrawn only when a zone changes hands.
`territory.margin` (70 km) extends the cells beyond the outer zones; `territory.hatch_spacing` (3,000 m) and `territory.hatch_length` (2,500 m) set the hatches' spacing and length; `territory.enabled: false` removes the tint.

## The debugging log {#debug-log}

While the campaign is being tuned, `dynamic.debug` (on by default) writes in `dcs.log` what the campaign does, in lines easy to search for:

| Tag | What it says |
|---|---|
| `[CAMPAIGN DECISION]` | every decision of the AI and its reason: a sortie sent, or not (no target, no airfield, no room left, nothing to pay with — with the price and the stock); a raid's package; a refusal examined again at every beat is told once, until its reason changes |
| `[CAMPAIGN FLIGHT]` | the fate of every campaign aircraft: a weapon released (with its distance to the aim, the nearest zone and what it has left), a kill or a loss and by whom, a landing (on an airfield, or in the open near a zone), a raid leaving its hold; a wreck crushing the scenery is not a kill |
| `[CAMPAIGN AIRDEF]` | every `debug_status_seconds` (300 s): for each zone, its air defence units and the missiles they have left, empty launchers included |
| `[CAMPAIGN SUPPLY]` | the network's deliveries ordered, arrived, lost |
| `[CAMPAIGN ZONE]` | zones captured and turned neutral |
| `[CAMPAIGN STATUS]` | every `debug_status_seconds` (300 s): per side, zones, stock and production, deliveries on their way, flights up, raid out, and the players' credits |

`debug: false` turns it off, once the campaign is trusted.

The credits earned are written whether `debug` is on or not:

- one line `CREDITS <pilot> +<amount> (<reason>)` per gain — `kill`, `kill_held`, `landed`, `warehouse` for a pilot; `capture`, `delivery`, `task`, `demolition` under `team`;
- a `CREDITS SUMMARY` at the mission's end, and as soon as nobody is left in a slot: what each earned since the previous summary, and the side's total;
- each pilot's total over the whole campaign, in the save (`parts.economy.pilots`), for the debrief.

## Checking a mission in game {#self-check}

F10 → Other → VEAF → Campaign → **Self-check (admin)** prints one `OK` or `KO` line per mechanism: zones placed, save read and written, outcome, dormancy, captures, factories, territory, both sides' resources, network (deliveries and zones cut off), paid spawns, sappers, warehouses, helicopters, air, bombers, credits, tasks, intelligence.
A `KO` line is enough to know where to look.

## Every setting {#settings}

| `dynamic:` key | Default | What it sets |
|---|---|---|
| `save_seconds` | 60 | interval between two saves |
| `wake_radius` | 60000 | metres: an enemy player this close wakes a zone |
| `ground_wake_radius` | 10000 | metres: an enemy ground group that is no garrison, this close, wakes a zone; vehicles placed in the editor wake nothing |
| `reach_wake_margin` | 20000 | metres: an enemy aircraft this far beyond a zone's air defence reach wakes it |
| `takeoff_threat_range` | 40000 | metres: nothing but a SEAD takes off this close to an enemy air defence measured |
| `min_runway_length` | 1500 | metres: no aeroplane of the AI leaves a field whose longest runway is shorter |
| `takeoff_timeout` | 600 | a flight still on the ground after this long is taken away, its price back |
| `grounded_seconds` | 3600 | a field that kept a flight on the ground sends no aeroplane for this long |
| `front_depth` | 40000 | metres: a zone this close to the front line drawn on the map is always awake |
| `sleep_seconds` | 600 | a zone with no player near it for this long goes back to sleep |
| `sleep_margin` | 20000 | metres added to an awake zone's wake distances before it goes back to sleep |
| `wake_rest_seconds` | 300 | a zone asleep for less than this does not wake for an AI aircraft |
| `wake_units_per_beat` | 10 | the units of a garrison that appear per beat, at a wake or after a capture; a group is never split |
| `max_awake_zones` | 12 | zones of the rear awake at once (the front and the targets of sorties do not count) |
| `attacks` | `[red]` | the sides that counter-attack on their own |
| `attack_seconds` | 900 | interval between two counter-attacks of a side |
| `max_convoys` | 2 | a side's assault convoys on the road |
| `supply` | `[red]` | the sides whose AI helicopters capture and resupply |
| `supply_seconds` | 600 | interval between two helicopters of a side |
| `max_helicopters` | 2 | a side's supply helicopters in the air |
| `helicopter_timeout` | 1200 | a helicopter not landed after this long is removed |
| `helicopter_capture_seconds` | 600 | a neutral zone held by landed helicopters alone is taken after this long |
| `helicopter_garrison` | 6 | the soldiers a capture by landed helicopters alone leaves; no vehicle |
| `convoy_timeout` | 2700 | the least time an assault convoy has before it is taken off the map, its place freed; else half as long again as its road needs |
| `assault_speed` | 40 | km/h: an assault convoy's speed |
| `convoy_report_seconds` | 300 | seconds between two `dcs.log` lines on an assault convoy's progress |
| `fall_back_seconds` | 120 | how long an assault convoy must fall back, without taking its road again, for its assault to be over |
| `retire_quiet_seconds` | 300 | a convoy to retire leaves only after this long without contact, and with no player within `wake_radius` |
| `route_failures` | 2 | helicopters or convoys failed in a row to a zone before the side gives it up |
| `route_failure_seconds` | 3600 | how long it gives it up |
| `helicopter` | `{red: Mi-8MT, blue: UH-1H}` | each side's helicopter type |
| `supply_crate` | `Zone supplies` | the name of the CTLD 2 crate that resupplies |
| `hunter` | `{enabled: true, ground_kills: 8, air_kills: 4, chance: 10}` | the Hunter |
| `air` | see [enemy air](#air) | `strike_seconds` (900), `max_flights` (4), `cap_per_players` (3), `cap_helicopter_chance` (25), and each side's aircraft |
| `economy` | see [the shop](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker`, `credits_per_point` (6), `demolition` (50), `warehouse_delivery` (50), `landing_share` (50) |
| `tasks` | see [the tasks](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`, `intercept`) |
| `intel` | see [intelligence](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |
| `resources` | see [the resources](#resources) | `enabled` (true), `start` (1000), `background_per_hour` (60), `reserve` (100), `prices` |
| `factory` | see [the factories](#zone-kinds) | `buildings` (3), `per_hour` (180), `types` |
| `network` | see [the network](#network) | `hop_seconds` (600), `isolated_seconds` (3600), `depot_store` (4), `max_deliveries` (3), `under_fire_seconds` (600), `depot_buildings` (3), `depot_types`, `depot_rebuild_seconds` (2700) |
| `demolition` | see [demolition](#demolition) | `troops` (`Sappers`), `range` (5000), `fuse` (120) |
| `warehouse` | see [the stocks](#warehouses) | `enabled` (true), `load` (10) |
| `bombers` | see [the bombers](#bombers) | `enabled` (true), `seconds` (3600), `min_distance` (80000), `escort` (false), `package_delay` (30) |
| `debug` | see [the debugging log](#debug-log) | `true` while testing |
| `debug_status_seconds` | 300 | seconds between two status lines of the log |
| `territory` | see [territory](#territory) | `enabled` (true), `margin` (70000), `hatch_spacing` (3000), `hatch_length` (2500) |
| `support` | see [AWACS and tankers](#support) and the [`veafSupport` module](scripts/veafSupport.en.md#settings) | `assets` (none), `margin` (30000), `retreat_margin` (50000), `seconds` (60), `advance_seconds` (1800), `min_advance` (30000), `leg` (30, nm) |

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
- the territory tint, made of triangles, on the F10 map;
- an AWACS or a tanker moved out of reach, and its leg across the axis;
- a supply helicopter told not to abort its task under a threat (twice on 2026-11-16 a Mi-8 sent from Aleppo to Afrin landed back at Aleppo three minutes after leaving: a probable cause, not a measured one);
- the waypoint numbers, as each module shows them;
- an airfield neutral or enemy at the start, captured in flight, offering its dynamic slots to the side that took it (Foothold relies on it; not measured on ours yet);
- a building destroyed counted in the ranking: DCS has to send an `S_EVENT_KILL` for a static object.

See also the [`veafCampaign` module reference](scripts/veafCampaign.en.md).
