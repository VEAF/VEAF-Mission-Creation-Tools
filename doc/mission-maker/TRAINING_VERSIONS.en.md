# Training versions, one per role

A mission night is shorter when the pilots have already flown its setting.
With a `training:` block in `mission.yaml`, the build produces, beside the night's mission, training versions on **the same setting**: same theatre, same date and time, same weather and wind, same scripted events, same flight plans and same slots.
Each version puts the mission in the state "the other roles have done their job", and what the briefing does not state changes at every launch: pilots train without learning the night's mission by heart.

## What the build produces {#outputs}

| File | For | What changes from the night |
|---|---|---|
| `<mission>.miz` | the night | nothing: it is the definitive mission |
| `<mission>_TRAINING_A2G.miz` | air-to-ground pilots | no enemy CAP, no QRA, no long-range SAM |
| `<mission>_TRAINING_CAP.miz` | air-to-air pilots | no A2G target, but all their air defences stay; the QRA is armed from the start |
| `<mission>_TRAINING_SEAD.miz` | SEAD pilots | no enemy CAP, no QRA, no A2G target; the long-range SAMs stay |
| `<mission>_TRAINING_ALL.miz` | training together | nothing is taken out |

The briefing is the same for all of them.
In the four training versions, the elements the briefing describes vaguely are drawn again at every launch (see [below](#draws)).

## Classifying the mission: `elements` {#elements}

Each entry says **what** an element of the night is, with exactly one selector:

| Selector | Names |
|---|---|
| `groups` | Mission Editor groups, by exact name or pattern (`"SA-10 *"`) |
| `zone` | a combat zone declared in `modules.COMBATZONE`, with every group it captures |
| `qra` | a QRA declared in `modules.QRA.definitions`, by its `name` |
| `cap_mission` | an on-demand CAP of `cap_missions`, by its `group_name` |

And a `kind` among:

| `kind` | A2G | CAP | SEAD | Common |
|---|---|---|---|---|
| `enemy_cap` — enemy CAP, an AI flight or an on-demand CAP | taken out | kept | taken out | kept |
| `qra` | taken out | kept and armed | taken out | kept |
| `sam_lr` — long-range SAM | taken out | kept | kept | kept |
| `a2g_target` — air-to-ground target | kept | taken out | taken out | kept |
| `sam_threat` — a SAM protecting an A2G zone, or a SEAD secondary objective | kept | kept | kept | kept |

An element nobody declares stays in every version.
In CAP, **every** air defence stays — a SAM, its radar or AAA, declared or not, even inside an `a2g_target` zone: a CAP flies through the zone's SAMs whatever the strikers have done.
In SEAD, only the declared SAMs stay (`sam_lr`, `sam_threat`): the zone's other groups go with its targets.

## Vague elements: `randomize` {#draws}

What the briefing states (type **and** number: "4 tanks covered by an SA-8") stays as it is.
What it describes vaguely ("an SA-6 with defences around it", "an armoured column") is declared in `randomize`: in the training versions, the groups it replaces leave their place, and a combat zone draws among its candidates at every launch.

```yaml
training:
  elements:
    - groups: ["SA-10 Gudauta"]
      kind: sam_lr
    - zone: Factory
      kind: a2g_target
    - groups: ["Factory-SA-6"]
      kind: sam_threat
  randomize:
    - name: factory-def                 # letters, digits, - and _
      replaces: ["Factory-SA-8 *"]      # the night's fixed groups
      pool:
        - group: "Factory-SA-8 #1"      # a group of the night, taken as it is
        - command: -sa15                # a VEAF shortcut (list_shortcuts)
        - units: [{type: Strela-10M3, count: 2}]   # a group made from DCS types
      count: 1-2                        # how many to draw: a number or min-max
      radius: 500-2000                  # scatter around their position, in metres
```

Three kinds of candidates:

- `group`: one of the replaced groups, **taken as it is** — type, units, loadout, skill.
  It must be listed by `replaces`.
- `command`: a VEAF shortcut, carried by a unit of the same kind as the replaced groups (an SA-8 for `-sa15`), so the editor draws the right threat ring; `carrier: <DCS type>` picks another.
- `units`: a ground group the build creates from DCS types.

The draw happens **when the mission starts**, through the combat-zone markers (`#spawngroup`, `#spawncount`, `#spawnradius`) the build writes into the unit names: each launch gives another result.
When the replaced groups already belong to a combat zone of the night, the draw happens in that zone; otherwise the build lays a `TRAINING-<name>` zone around them, active from the start, with no radio menu.
`at: {x, y}` places the draw somewhere other than on the replaced groups.

## What is refused, and why {#refusals}

The build and `validate_mission` refuse the block, naming each problem:

- a selector that names nothing, an unknown zone, QRA or CAP;
- a group declared twice with two different `kind`s, or both classified and drawn;
- a `group` candidate missing from `replaces`, an unknown shortcut, a DCS type that is unknown or not a ground unit;
- a `count` larger than the number of candidates;
- a group taken into a draw **and named elsewhere** — by a trigger's script, a module of `mission.yaml` or a mission script.
  For the zone to capture it the build must rename it, which would break that reference with no message from DCS; keep it fixed, or replace it with new candidates;
- a taken group carrying a `#veafInterpreter`: its command runs once at mission start, so there is nothing left to draw;
- `training:` beside `build_variants:`: the combination would make eight missions nobody asked for.

## Building {#build}

Nothing more than the usual build, from the mission folder:

```powershell
.\veaf-tools.exe build
```

The build announces the five missions then, for each training version, how many groups it took out and how many draws it laid.
For one version only: `.\veaf-tools.exe build --profile TRAINING_SEAD`.

## With the AI assistant {#with-the-ai}

Tell it *"also build the training versions"*.
It proposes a classification from the mission's data (`propose_training_plan`), checks it against the briefing to sort what is stated from what is vague, shows it to you, then writes it (`set_training_plan`) and builds.
See the [action catalogue](AI_ASSISTANT_CATALOG.en.md#training-versions).
