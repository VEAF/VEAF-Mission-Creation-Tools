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
- **The front moves on its own**: the enemy [counter-attacks](#front), reinforces its zones by helicopter, and sends CAP and strikes.
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

`campaign next` also adds to the mission's `ctld-config.yaml` what the players carry for the campaign: the **"Zone supplies"** crate (one per side) and the **"Spy"** troop group (one man).

## The save {#save}

The mission writes its state every `save_seconds` (60 s) and at mission end to:

```text
<Saved Games>\DCS\Missions\Saves\<campaign name>\persistent.state
```

At start it reads that file back: each zone takes back its owner, its garrison with its losses, and its capture in progress; the credits and the current intelligence come back too.
A zone added to `campaign.yaml` since starts from its declared state; a zone removed is ignored, and the log says so.

What is **not** restored after a restart: the aircraft, helicopters and convoys under way. They are lost; the zones and garrisons are not, and the survivors of a convoy paid from a reserve go back to it.

The file is a Lua table read with no access to anything: it cannot run code.
The server's `MissionScripting.lua` must leave `io` and `lfs` open, as the VEAF servers do.
Without them the campaign runs anyway, but does not save, and says so once.

**Reset**: F10 → Other → Campaign → **Reset the campaign (admin)**.
The campaign starts again from its declared state at the next load of the mission; a victory or a defeat does the same.

## Sleeping zones {#dormancy}

Away from the players, a zone has no unit in the world: its garrison is only a line of the save, losses included.
It appears when a player's aircraft comes within `wake_radius` (60 km) or a sortie targets it, exactly as it was, and disappears when nobody has come near for `sleep_seconds` (600 s).
At most `max_awake_zones` (12) zones are awake at once, nearest the players first, and only one wakes per 10-second beat, so the whole front does not appear in one go.

## A front that moves on its own {#front}

- **Counter-attacks**: every `attack_seconds` (900 s), a side listed in `attacks` (red by default) sends an assault convoy against the weakest enemy zone it borders, `max_convoys` (2) on the road at most.
- **Resupply**: a delivery to a damaged friendly zone brings its first damaged group back to full strength.
  Deliveries are: a "Zone supplies" crate set down in the zone, CTLD 2 troops deployed in the zone (the spy team and the JTAC teams excepted), a supply helicopter landed in it.
- **AI helicopters**: every `supply_seconds` (600 s), a side listed in `supply` (red by default) sends a helicopter (`helicopter`, a Mi-8MT for red, a UH-1H for blue) to a neutral zone it borders, which it takes by landing there, or else to its most damaged zone, which it resupplies; `max_helicopters` (2) in the air at most, and one that has not landed after `helicopter_timeout` (1,200 s) is removed.

## Enemy air {#air}

- **CAP**: the enemy keeps one CAP up per `air.cap_per_players` (3) players of the [opposition level](scripts/veafQraManager.en.md#opposition-level), at least one, over its front zone nearest the players.
- **Strikes**: every `air.strike_seconds` (900 s), a CAS strike (on the zone with the most units) or a SEAD strike (on the one with the most air defence), in turn, on a zone bordering the enemy's territory.
- They take off from the nearest enemy airfield; no airfield, no sortie.
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
| Capture helicopter | a helicopter that goes and takes a neutral zone | 250 |
| Resupply helicopter | a helicopter that goes and resupplies one of our damaged zones | 200 |
| Tanker | respawns the tanker `economy.tanker` names (an asset of the mission); absent without it | 300 |

Prices change in `economy.prices` (`jtac`, `illumination`, `smoke`, `intel`, `cap`, `capture`, `resupply`, `tanker`).

## The task board {#tasks}

F10 → Other → Campaign → **Tasks**: `tasks.count` (3) tasks at once, drawn from the situation and filled up every `tasks.refresh_seconds` (300 s), each marked on our side's map.

| Task | Done when | Reward |
|---|---|---|
| Attack the weakest enemy zone on the front | it is no longer the enemy's | 300 |
| Capture a neutral zone bordering ours | it is ours | 300 |
| Resupply our most damaged zone | it is back to full strength | 200 |
| Air superiority | `tasks.air_kills` (2) aircraft shot down | 200 |

A task whose target went to the enemy is withdrawn, without reward.

## Intelligence {#intel}

An enemy zone's garrison is **unknown** to the players ("strength unknown" on the map) until it is reconnoitred, for `intel.seconds` (one hour):

- by an **overflight**: a player's aircraft within the zone's circle, less than `intel.overflight_altitude` (1,500 m) above the ground;
- by a **JTAC drone** or **intel** bought in the shop;
- by a **spy team**: the "Spy" CTLD 2 troop group deployed within `intel.spy_range` (5 km) of an enemy zone walks into it on its own, and reveals it on arrival.

A reconnoitred zone shows its strength on the map, and F10 → Other → Campaign → **Intel** gives its composition, air defence first.
`intel.hidden: false` shows every garrison to everyone.

## Checking a mission in game {#self-check}

F10 → Other → Campaign → **Self-check (admin)** prints one `OK` or `KO` line per mechanism: zones placed, save read and written, outcome, dormancy, captures, helicopters, air, credits, tasks, intelligence.
A `KO` line is enough to know where to look.

## Every setting {#settings}

| `dynamic:` key | Default | What it sets |
|---|---|---|
| `save_seconds` | 60 | interval between two saves |
| `wake_radius` | 60000 | metres: a player this close wakes a zone |
| `sleep_seconds` | 600 | a zone with no player near it for this long goes back to sleep |
| `max_awake_zones` | 12 | zones awake at once |
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
| `economy` | see [the shop](#shop) | `start_credits`, `kill_ground`, `kill_air`, `capture`, `delivery`, `prices`, `tanker` |
| `tasks` | see [the tasks](#tasks) | `count`, `refresh_seconds`, `air_kills`, `rewards` (`attack`, `capture`, `resupply`, `air`) |
| `intel` | see [intelligence](#intel) | `hidden`, `seconds`, `overflight_altitude`, `spy_troops`, `spy_range` |

The caps are conservative by default; they will be tuned from what the servers hold.

## Still to check in game {#to-verify}

These are written and tested outside DCS, not yet measured in game:

- an AI helicopter landing in a zone (DCS's known traps on a scripted landing are in [the DCS runtime traps](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/agents/dcs-runtime-traps.md));
- the CAS and SEAD strikes air-started over their airfield, and their return;
- the spy team walking to its zone;
- a garrison disappearing and reappearing as a player passes.

See also the [`veafCampaign` module reference](scripts/veafCampaign.en.md).
