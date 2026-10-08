# Multi-mission campaign

> A campaign for the squadron, flown mission after mission.
> Each mission starts from what the last one left: a bridge destroyed stays destroyed, a base freed stays ours, a garrison that lost two launchers has lost them for good.
> It is an **episodic** campaign, in the spirit of DCS Liberation: each mission is a bounded flying session, and the campaign moves on between two missions.

## The loop {#loop}

| step | who | how |
|---|---|---|
| declare the campaign | the mission maker, often with Claude | a campaign folder and its `campaign.yaml` |
| start | the tools | `campaign init` creates the starting state |
| build mission N | the tools, then Claude | `campaign next` prepares the mission folder from the state; Claude designs the mission in it through the MCP |
| fly | the squadron | the mission writes its **state file** during the flight and at its end |
| fetch the state file | the mission maker or Claude | from the server's `Saved Games` |
| apply | the tools | `campaign apply` merges the state file and plays the turn between missions |

Then back to `campaign next`, until the objectives are met or the planned missions have been flown.

```powershell
.\veaf-tools.exe campaign init C:\Campaigns\Caucasus
.\veaf-tools.exe campaign next C:\Campaigns\Caucasus
# … the mission is designed, built, flown …
.\veaf-tools.exe campaign apply "C:\Saved Games\DCS\Missions\Saves\Caucasus Front\mission-01.state" C:\Campaigns\Caucasus
.\veaf-tools.exe campaign next C:\Campaigns\Caucasus
```

With the AI assistant, the same steps go through the `campaign_status`, `campaign_apply` and `campaign_next` actions (see the [catalogue](AI_ASSISTANT_CATALOG.en.md)).

## The campaign folder {#campaign-folder}

```text
Caucasus/
├── campaign.yaml            what you declare; the tools never rewrite it
├── briefing.yaml            the text of the campaign briefing (see below); optional
├── campaign-state.yaml      what the campaign has become; rewritten after every mission
├── template/                an ordinary mission folder: every mission starts from it
└── missions/
    ├── mission-01/
    │   ├── mission/         the mission folder of mission 1
    │   ├── mission-01.state the state file the mission wrote
    │   ├── briefing-campagne.pptx / carte-strategique.png
    │   ├── briefing-mission.pptx / carte-tactique.png / zoom-<zone>.png
    │   ├── debriefing.fr.txt / debriefing.en.txt
    │   ├── campaign-state.before.yaml
    │   └── campaign-state.after.yaml
    └── mission-02/
        └── mission/
```

`template/` is prepared once, like any mission folder (`.\veaf-tools.exe prepare`, or the MCP action `scaffold_mission`): the map, the slots, the presets, the scripts.
Every mission of the campaign starts as a copy of it.

The history is kept whole: to undo a merge, put `campaign-state.before.yaml` back in place of `campaign-state.yaml`.

## Declaring a campaign {#declare}

```yaml
campaign:
  name: Caucasus Front
  theatre: Caucasus
  era: MODERN                # MODERN, COLD_WAR or WW2: what the garrisons draw
  missions: 10               # the objectives are sized for about this many
  player_side: blue          # the players' side; blue by default
  capture_seconds: 120       # ground presence needed to take a neutral zone
  state_write_seconds: 60    # how often the state file is written in flight
  start_date: 2016-06-01     # the first mission's date; the template's otherwise
  start_time: sunrise+30*60  # start time: "06:30" or a solar expression; this is the default
  players: 5-7               # the squadron's expected size: a count (6) or a range
  objectives:
    - capture: [Senaki, Kutaisi]
    - destroy: { zone: Gudauta depot, kind: logistics }
size_classes:                # override the shipped classes, or declare new ones
  outpost: { size: 2 }
zones:
  - name: Kobuleti
    at: { airfield: Kobuleti }
    size: airfield
    side: blue
  - name: Senaki
    at: { airfield: Senaki-Kolkhi }
    size: airfield
    side: red
    radius: 3000             # in metres; 2000 by default
  - name: Gudauta depot
    at: { lat: 43.10, lon: 40.58 }
    size: outpost
    side: red
    kind: logistics          # feeds its side's reserve between missions
    display_name: Gudauta depot      # the name the players read; the name stays the key
    intel: Active depot, guarded.    # what the intelligence says, in place of the generated text
    garrison: [sa8, shilka, T-72B]   # replaces the draw, for the side declaring it
connections:
  - [Kobuleti, Senaki]
  - [Senaki, Gudauta depot]
sides:
  red: { reserve: { armor: 12, air_defense: 4, transport: 6 } }
rules:
  repairs_per_mission: 4
  assault_seconds: 600       # delay before an assault convoy leaves (see "In flight")
  intel_seconds: 1200        # delay before the other side hears it left; 0: at once
```

A complete campaign, ready to copy — western Georgia in 12 zones and 10 missions — ships with the tools: [`src/defaults/campaign-folder/campaign.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/defaults/campaign-folder/campaign.yaml).

A zone is **on an airfield** (`at: { airfield: <DCS name> }`) or **at coordinates** (`at: { lat, lon }`).
An airfield zone gives its base to its owner: dynamic slots for its side, none for a neutral base.

A `capture` objective is met when the players' side holds every zone it names.
A `destroy` objective is met when the enemy no longer holds the zone: its garrison destroyed, or the zone taken.

`.\veaf-tools.exe campaign validate <folder>` checks the file, and the state against it: unknown airfield, duplicate zone, connection to an unknown zone, a graph in pieces, an objective on an unknown zone, an unknown garrison alias, a parameter out of range.
A zone renamed or removed in `campaign.yaml` after the start is reported, never silently forgotten.

## Garrisons {#garrisons}

A garrison is drawn **once** by the CAS mission generators (`veafCasMission`), for the side holding the zone and the campaign's era.
Its composition is recorded, and every following mission spawns it again **minus its losses**: a SAM site that lost two launchers starts without them.
A zone that loses its whole garrison turns **neutral**, and can be captured.

### Size classes {#size-classes}

A size class is a set of parameters of the CAS generators: the garrison has as many infantry sections, armour platoons and air defence groups as a CAS mission of the same size, **without its transport company** — a garrison has no use for fifteen lorries.

| shipped class | `size` | `defense` | `armor` | long-range SAM | units (average, min – max) |
|---|---|---|---|---|---|
| `outpost` | 1 | 1 | 1 | no | 23 (12 – 36) |
| `airfield` | 1 | 3 | 2 | yes | 51 (35 – 74), of which ≈ 20 for the SAM |

Measured over 40 draws on 2026-10-06; the example campaign thus has about 470 ground units.

`size` runs from 1 to 5, `defense` and `armor` from 0 to 5, as for a `_cas` marker.
A new class must set `size`, `defense` and `armor`.

### Before the first mission {#first-mission}

The starting garrisons are drawn by mission 1 itself, in game.
The first briefing therefore speaks in intelligence terms ("estimated strength"); the real figures come with mission 1's state file.

## In flight {#in-flight}

- The **F10 map** shows each zone as a circle in its owner's colour, with its name and its garrison's strength, and the connections as dashed lines.
- The **Campaign → Situation** radio menu gives the zones, the objectives and the mission number.
- **Taking a neutral zone**: ground units of a single side stay there for `capture_seconds` (120 s by default) — CTLD 2 troops or vehicles, a convoy, a `_spawn` group, a Combined Arms vehicle, a **landed** helicopter, a CTLD 2 crate.
  Both sides present stop the clock; everybody gone cancels it.
  An aircraft in flight never counts, nor does a wreck.
  The DCS log (`dcs.log`) says, at each change, who holds a neutral zone and through which unit: that is where to read why a capture does not start.
  The zone taken gets its new side's garrison at once, paid from that side's reserve — unless an assault convoy takes it: its survivors become the garrison.

### Assault convoys {#assault-convoys}

A neutral zone is the target of every side that holds a neighbouring (connected) zone.
After `rules.assault_seconds` (600 s by default, sooner when the [opposition level](scripts/veafQraManager.en.md#opposition-level) is above 4 players: half as long at 8), a convoy leaves by road from that side's first neighbour for the target — for a mission starting with a neutral zone as for a zone turning neutral in flight.
One convoy at a time per side and target; it does not leave if its start zone changed hands.
It is armour after its start zone's size class plus a few trucks, **paid from its side's reserve**, unit by unit; an empty reserve sends nothing.
It behaves like any convoy under fire ([veafGroundAI](scripts/veafGroundAI.en.md)): it watches ahead, splits, calls for help, falls back.
Its side is told it leaves and sees its axis on the F10 map at once: a line in its colour, over the link, until it arrives or is destroyed.
The other side hears of it as intelligence `rules.intel_seconds` later (1,200 s, 20 minutes, by default; 0: at once): the message ("an enemy column is leaving Senaki towards Poti") and the same line on its map come together, and a convoy destroyed before then is never reported.
Once there, it holds the zone like any ground unit and takes it after `capture_seconds`: its survivors in the zone become the garrison, with no second draw from the reserve.
Blue players also send them from the **Campaign → Assaults** menu, from a blue zone to a neighbour that is not, at the mission's security level.
`rules.assault_convoys: false` turns the rule off; the menu stays.

## The state file {#state-file}

The mission writes everything the next one depends on — each zone's owner, garrisons and losses, reserves, destroyed scenery, the missiles the SAMs have left, the warehouses' content — to:

```text
<Saved Games>\DCS\Missions\Saves\<campaign name>\mission-NN.state
```

It writes it every `state_write_seconds` during the flight, and at the end of the mission: a server that crashes loses one interval at most.
Every write starts with a complete temporary (`mission-NN.state.tmp`).
When `os` is available the temporary replaces the file; otherwise the file is written in turn.
Either way a write cut short leaves a whole file behind, and `campaign apply` falls back on the temporary when the file itself is cut short.

The mission scripting environment needs `io` and `lfs` (`MissionScripting.lua` not sanitizing those two).
The VEAF servers sanitize only `os` and `loadlib` (measured 2026-10-03).
Without `io` or `lfs`, the mission says so once and runs anyway: the campaign simply cannot record it.

### Fetching the file from a server {#fetch-state}

The file is in the `Saved Games` of the DCS instance that ran the mission: on dcs.veaf.org, `C:/Users/veaf/Saved Games/<instance>_server/Missions/Saves/<campaign name>/`, reachable over SFTP.
Copy `mission-NN.state` to your machine — with its `.tmp` when there is one — then pass its path to `campaign apply`.

## Between missions {#between-missions}

`campaign apply` refuses a file already applied, one from another campaign, or one that skips a mission; in those cases nothing is written.
Otherwise it merges the file, then plays the **turn** with fixed rules, for both sides:

| rule | setting | default |
|---|---|---|
| each `logistics` zone held feeds its side's reserve | `rules.logistics_output` | `{armor: 2, air_defense: 1, transport: 1}` |
| lost units are replaced from the reserve, category by category | `rules.repairs_per_mission` | 4 units per side |
| a neutral zone bordered by a single side is retaken by it | `rules.counter_attack` | `true` |
| an assault convoy still on the road when the flight ends returns its survivors to its side's reserve; its dead are campaign losses | — | — |

Destroying an enemy depot means a smaller reserve, so fewer repairs and thinner garrisons behind it: an empty reserve only allows a token garrison.

The enemy's **intent** — where it puts its effort, what the next mission asks of the players — is not in the rules: Claude decides it while building the next mission, and writes it in the briefing.

## The opposition sized to the squadron {#players}

What scales with the number of players is the **enemy air**: the QRAs and the on-demand CAPs.
The ground garrisons are the campaign's books — reserves, losses, repairs — and do not depend on who came tonight.

`players` in `campaign.yaml` says the usual attendance; `campaign next --players 6` says tonight's, and wins:

```powershell
.\veaf-tools.exe campaign next . --players 6
```

`campaign next` then writes the mission's [`opposition:`](scripts/veafQraManager.en.md#opposition-level) block: a level equal to the most expected, which then follows the players connected on the players' side — if the squadron comes four-strong, the opposition comes down to four after a few minutes.
A second `campaign next` on the same folder changes the level only: a follow mode or a delay set in the mission since is kept.
With neither `players` nor `--players`, the mission's block is left alone.

The mission's enemy QRAs need tiers up to that size (`groups_by_enemy_count`); Claude writes them when designing the mission.
The mission briefing says it as intelligence — "the enemy reinforces its alert against a large package" — never as tiers or numbers.
It likewise announces an [expected ground counter-attack](#assault-convoys) towards a neutral zone the enemy borders, without its strength.

## The debriefing {#debriefing}

`campaign apply` also writes the debriefing of the mission flown, in French and English, in `missions/mission-NN/` (`debriefing.fr.txt`, `debriefing.en.txt`): the ground that changed hands, each side's losses zone by zone and unit type by unit type, the scenery destroyed, what the turn did next, and where the objectives stand.
It is a text to read after the evening or to post as it is; the AI assistant tells it as a story for the squadron when asked, keeping to its facts.

## The strategic briefing {#strategic-briefing}

`campaign next` writes, at the root of the mission folder, the factual part of the strategic briefing in French and English (`strategic-situation.fr.txt`, `strategic-situation.en.txt`): the front, what changed in the last mission, the enemy's reserve and garrisons, the objectives and the missions left.
The text, in the language the tools run in, also becomes the mission's briefing when the folder is created, so a mission built as it is does not fly without one; Claude adds the narrative part while designing the mission, and a second `campaign next` on the same folder does not overwrite it.

## A mission's date, time and weather {#mission-conditions}

A campaign mission is **one** mission: no weather variants.
The folder `campaign next` creates has `pipeline.weather: false` as the last block of `mission.yaml` and no `src/versions.yaml`; date, time and weather are **fixed in the mission** itself.

- **The date moves on with the campaign**: mission N+1 takes place the day after mission N, whose date `campaign apply` keeps in the campaign state. The first one takes `start_date` from `campaign.yaml`, or the template's date.
- **The time serves the mission**: `start_time` from `campaign.yaml`, a clock time (`"06:30"`) or a solar expression (`sunrise+30*60`, the default). The expression is computed for the campaign's ground — the centre of its zones — and the mission's date, on the theatre's clock: sunrise over Colchis, not over Damascus as the shipped `versions.yaml` has it.
- **The weather may change from one mission to the next, the ground stays visible**: no clouds, few or scattered, based between 1,500 and 3,500 m, visibility 8 km or more, neither fog nor rain — CAVOK or nearly. The draw depends on the campaign's name and the mission's number: the same mission draws the same sky again.

DCS rains only under its "rainy" clouds, which are overcast: light rain under a clear sky does not exist, so a campaign's weather never has rain.

What `campaign next` set is a starting point: Claude, preparing the mission, moves the date on when the story wants it and sets the hour the mission needs (action `set_mission_date`), and may change the weather (`set_weather`) while keeping the ground visible.
A second `campaign next` on the same folder keeps what was set.
The DCS briefing shows the mission's date, time and weather; the mission briefing writes them too.

## The campaign briefing deck {#briefing-deck}

`campaign next` also writes, in `missions/mission-NN/`, the **campaign's strategic briefing** as a PPTX (`briefing-campagne.pptx`) and its map (`carte-strategique.png`).
It is a situation brief after the VEAF briefing template — 16:9, white, bold title top left — that imports as it is into Google Slides.
`.\veaf-tools.exe campaign briefing <folder>` regenerates it at any time, for instance after touching up the text.

| Page | Where it comes from |
|---|---|
| Strategic situation — political, economic | `briefing.yaml` |
| Military situation — enemy forces, friendly forces, neutral ground | the tools, and the enemy's course of action from `briefing.yaml` |
| Strategic map | the tools: each zone at its radius, in its owner's colour, and the axes |
| Mission and intent — mission, purpose, main effect, method, end state | `briefing.yaml` |
| Campaign objectives — political, military, economic, conditions of victory | `briefing.yaml`, and the objectives of `campaign.yaml` |
| Concept of operations — one phase per mission, points of attention | `briefing.yaml` |
| Rules of engagement — targeting, protection of civilians and infrastructure, self-defence | `briefing.yaml` |
| Mission N — its tasks | `briefing.yaml` |
| Annex — Campaign rules | the tools, from the rules of `campaign.yaml` |

**Facts are generated, prose is written.**
The tools write what the campaign knows; the situation, intent, concept and rules of engagement are written in `briefing.yaml`, next to `campaign.yaml`, by Claude or by hand.
Without `briefing.yaml`, the deck holds the generated part only, and says so; `campaign validate` checks the file.
Only the annex speaks of the game's mechanics: the rest reads as a staff would speak.

**The enemy stays mysterious.**
The deck never gives an enemy strength, nor its reserve: only what the intelligence says of it, with the reliability of its source.
A fixed site — a zone's long-range SAM — is named as soon as the campaign state records it: its battery is drawn when the mission starts, so it is "likely, type unconfirmed" before mission 1, then named ("SA-10 battery confirmed") from mission 2 on.
A zone can carry its own intelligence text (`intel:`) and the name the players read (`display_name: Khobi depot`).

```yaml
operation: Kolkhida
situation:
  political:
    - Ten days ago, red forces crossed the Inguri and gained a foothold in the Colchis plain.
    - Negotiations are opening; every kilometre the enemy holds when they do will be his.
  economic: The port of Poti has stopped working.
  enemy_course_of_action: Hold Senaki under its air defence, then resume the offensive.
mission: In 3 missions, the coalition retakes Senaki and destroys the Khobi depot.
intent:
  purpose: Deprive the enemy of the means to resume the offensive.
  main_effect: Cut Senaki off from its logistic support.
  end_state: Senaki and Poti held, Khobi destroyed, the towns spared.
objectives:
  political: [Restore the government's authority up to the Inguri.]
  military: [Retake Senaki airfield., Destroy the Khobi depot.]
  economic: [Reopen the port of Poti, intact.]
concept:
  phases:
    - { title: "Phase 1 — mission 1: the gate of Poti", text: Take Poti and start wearing down Khobi. }
  attention: [Zugdidi is not an objective.]
rules_of_engagement:
  targeting: [Positive identification of every target before firing.]
  civilians: [No area bombing in built-up areas.]
  self_defence: [The right of self-defence is never restricted.]
missions:
  1:
    title: The gate of Poti
    tasks:
      - { title: Take Poti — priority 1, text: Secure the port with heliborne troops. }
```

Each text is a string or a list of paragraphs.
A text holding ": " goes in quotes (`"Targets: red units."`): without them YAML reads it as a key and its value, and `campaign validate` says so.
After each mission, the coming mission's page and the concept's progress are rewritten from the debriefing; the rest is kept as long as the situation does not change it.

The map is drawn on OpenStreetMap tiles, cached in `%LOCALAPPDATA%\veaf-tools\tiles`; the tools identify themselves to the server by their GitHub address, and nothing else.
Without the network, the map is drawn on a plain background and the deck says so: run `campaign briefing` again once online.

## The mission briefing {#mission-briefing}

Next to the campaign briefing, each mission has its **mission briefing**: `missions/mission-NN/briefing-mission.pptx`, after the VEAF mission briefing, with its tactical map (`carte-tactique.png`) and one zoom per objective (`zoom-<zone>.png`).
It is read from the **built** mission: `campaign briefing` writes it as soon as a `.miz` exists in `missions/mission-NN/mission` (at its root or in `build/`), and says how to get one otherwise.
Run `campaign briefing` again after every change to the mission.

| Page | What it says |
|---|---|
| Cover | the operation and the mission's number, its title (`briefing.yaml`), the date and time |
| General situation | context, mission (the tasks), bullseye (DMS, bearing and range from a friendly base), departures, threat (the intelligence, and the enemy's interception alert), weather and time **read from the mission** |
| ATO | the players' flights (callsign, type, count, base, pilot lines, free loadout), the airfields with dynamic slots, the support (AWACS, tankers) with frequency and TACAN, the control (the carrier's tower in VHF, airfields) |
| Tactical situation | zones, axes, interception alert zone, carrier, AWACS orbit, tanker track, bullseye, a scale in nm |
| One page per objective | the zone at its radius, its intelligence, the task naming it |
| Mission flow | objectives, air opposition, air defences, other information (refuelling, diversion fields, rescue) |
| Frequency plan | UHF then VHF, guard first |
| Objective coordinates | each zone's centre in DMS, and its elevation when a terrain grid has been swept (`terrain-sweep`) |

The objectives are the zones the mission's task titles name in `briefing.yaml` ("Frapper le dépôt de Khobi" names the zone *Dépôt de Khobi*), or else the campaign's objectives.
The flights are the players': neither the dynamic-slot templates nor the VEAF spawn templates are flights; a support aircraft appears once, by its task; the wind is said from where it comes, as a pilot reads it.

**No target coordinate and no flight plan**: a garrison is drawn when the mission starts, so no unit's position is known when the briefing is written, and it says so — exact positions are found in flight.
The maps' labels never overlap one another or a symbol.

## What is still to verify in game {#to-verify}

These points are written and tested outside DCS, but not measured in game yet:

- what `Airbase.setCoalition` and `Airbase.autoCapture(false)` do to the dynamic slots and warehouses of a base changing sides;
- how exact the warehouse content read in flight is, and writing it back into the next mission (not done yet);
- whether a SAM can start a mission with fewer missiles (the count left is recorded, not replayed yet);
- how to make a bridge or a building start destroyed (the destroyed scenery is recorded, not replayed yet);
- where airfield garrisons stand, drawn around the base's centre.

See also the [`veafCampaign` module reference](scripts/veafCampaign.en.md).
