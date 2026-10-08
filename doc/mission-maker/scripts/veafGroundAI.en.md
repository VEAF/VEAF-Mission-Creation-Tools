# veafGroundAI — Artillery from a marker, and convoys under fire

**Module ID:** `GROUNDAI` | **File:** `veafGroundAI.lua`

---

## Purpose

Gives a group of ground vehicles an **autopilot** that players command from the F10 map, with the
`_gc` marker. Two kinds of autopilot exist:

- **artillery** (`ArtilleryUnitHandler`), told to shell a set of coordinates — a few rounds to range in, then a fire-for-effect;
- **the convoy** (`ConvoyUnitHandler`), which looks after itself: it watches ahead for the enemy, splits when it sees one, calls for air support and falls back behind cover ([convoys under fire](#convoy)).

The module is **enabled by default** (`veaf.registerModule(..., { enable = true }, 190)`), and its
commands are reserved to **pilots the server knows**: `KNOWN_PILOT`, meaning anyone listed in
`veaf-pilots.txt`. An unlisted pilot must supply the matching password.

---

## Dependencies

- `veafCommands` — receives the marker and applies the security check
- `veafSecurity` — the `KNOWN_PILOT` tier
- `veafShortcuts` — the `-ai_set` alias and the `-arty*` family (optional, but the common way in)

---

## The `_gc` marker {#marker-command}

`_gc`, for *ground commander*. A pilot places a marker on the F10 map and writes:

```
_gc <name>, <verb> <value>, <parameter value>, ...
```

**The addressee first**, the way you would say it on the radio. The `<name>` is the one you give the
autopilot — you choose it, and you reuse it for every order you give it.

| What you write | What it does |
|---|---|
| `_gc arty-1` *(marker on the battery)* | creates the `arty-1` autopilot and starts it |
| `_gc arty-1, groupname ARTY-1` | the same, naming the DCS group instead of searching for it |
| `_gc mybattery, groupname arty-1` | the same, on a group created by a VEAF command |
| `_gc arty-1, aim 37T GG 12345 12345` | ranging fire on that position |
| `_gc arty-1, correction 09050` | shifts the last aim point and fires again ([adjusting the fire](#fire-adjustment)) |
| `_gc arty-1, fire` | fire for effect at the last aim point |
| `_gc arty-1, fire 37T GG 12345 12345, shells 40-80` | fire for effect on a given position |
| `_gc arty-1, status` | shows what the battery is doing |
| `_gc arty-1, stop` | stops it; its orders stay in memory |
| `_gc arty-1, clear` | stops it **and** clears its orders |
| `_gc arty-1, start` | restarts a stopped autopilot |
| `_gc arty-1, unset` | stops it and forgets it entirely |

**Writing `_gc <name>` on its own is the same as writing `_gc <name>, set`.**

### The parameters

| Parameter | Description |
|-----------|-------------|
| `groupname` | The name of the DCS group to drive. **A fragment is enough**: the group `-arty, unitname arty-1` creates is really called `[b]-arty-1#7`, and `groupname arty-1` finds it. If several groups match, the command is refused and you are told which names it found, rather than one being picked at random. On a `set`, if you leave the parameter out, the module looks for the allied group **nearest the marker, within 250 metres** — and tells you if it finds none. |
| `target` | The coordinates, if you would rather write them separately than after `aim` or `fire` ([the accepted formats](#coordinate-formats)). |
| `shells` | Number of rounds. Accepts a random range, e.g. `40-80`. |
| `radius` | Dispersion of the fire, in metres. Also accepts a range. |

`correct` can also be spelled `correction`: both work, so there is nothing to remember.

```
_gc arty-1
_gc arty-1, radius 15-30, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80, radius 50-150
```

> **The old syntax still works.** `_ground order, name arty-1, order aim; target …` is still accepted so
> that no existing mission breaks, but it is no longer documented: it needed a semicolon where the whole
> of the rest of VEAF uses a comma, and that was its only trap.

---

## The three orders {#order-syntax}

| Order | Effect | Default rounds | Default radius |
|-------|--------|----------------|----------------|
| `aim` | Ranging fire: a few rounds to adjust | 2 | 10 m |
| `fire` | Fire for effect | 40 | 100 m |
| `correct` *(or `correction`)* | Shifts the last aim point and fires again | 2 | 10 m |

`aim` and `fire` take the coordinates **right after the word**: `aim 37T GG 12345 12345`. `correct`
takes its offset the same way: `correction 09050`.

**`fire` with no coordinates fires again at the last aim point** — which is what lets you chain a ranging
order and then the effect without giving the position twice.

Both values are **validated as they are read**: a position or an offset the module cannot read is refused
and announced, never guessed at. A number a gun acts on is not something to guess.

```
_gc arty-1, radius 15-30, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80, radius 50-150
```

### The coordinate formats accepted {#coordinate-formats}

A `target` accepts any of these. They work **anywhere VEAF reads a coordinate** — AirWaves zones, named
points, QRAs, aliases — because one reader handles them all.

| What you write | What it is | Precision |
|---|---|---|
| `37T GG 12345 12345` | MGRS **exactly as DCS displays it** | 1 m |
| `37TGG12345678` | the same, without the spaces | 10 m |
| `u37TGG123456` | the older VEAF syntax, still valid | 100 m |
| `N42:30:15E041:45:30` | degrees, minutes, seconds | ~30 m |
| `N42 30 15 E041 45 30` | the same, separated by spaces | ~30 m |
| `N42°30'15"E041°45'30"` | the same, with the symbols | ~30 m |
| `N42:30.5E041:45.5` | degrees and decimal minutes | ~2 m |
| `N42.50416E041.75833` | decimal degrees | ~1 m |
| `N42E041` | whole degrees | ~100 km |

**The MGRS digit count is the precision**: two digits a side is 10 km, five is one metre. An **odd** digit
count is refused rather than guessed — it is a typo, and halving it would produce a position nobody asked
for.

`S` and `W` give the negative values. Case does not matter.

**The practical advice**: read the coordinates off your own screen and copy them as they are. The MGRS form
DCS shows is accepted untouched, and it is the hardest to mis-transcribe.

### Adjusting the fire {#fire-adjustment}

A battery remembers **the last point it aimed at**, and `correct` shifts that point. This is the classic
adjustment loop: fire, watch where the rounds land, call the correction in.

```
_gc arty-1, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80
```

The bearing is **always written as three digits**, because `090` and `90` would be the same string once
the distance is appended: `09050` is 50 m east, whereas `9050` would read as a bearing of 905 and be
refused.

Two corrections **compound**: two `09050` in a row and the aim point has moved 100 m east. A later
`fire` with no target then fires at the corrected point — it is the one aim point both orders share.

A correction is refused, and the refusal is announced to the pilot, in two cases: when it cannot be read
(the message then recalls the expected form), and when the battery has **no fire mission** to correct —
firing at the offset alone would put the rounds wherever the battery happens to stand.

---

## Convoys under fire {#convoy}

Left to itself, a DCS convoy drives through an ambush at full speed without firing a round, and dies.
Measured on 2026-10-08: four vehicles destroyed out of four, no return fire; and when it is given a new route under fire, only its lead obeys while the rest of the column stays where it is.
The convoy autopilot does the work instead, **with nobody at the controls**.

### What it does by itself {#convoy-behaviour}

1. **It watches.** Every 30 s it looks for enemy vehicles within 5 km (plus a minute of driving at its speed). While there are some, it checks every 3 s whether it can see them — terrain in between counts, vegetation does not (see the [limits](#limitations)).
2. **It reacts to the first one that matters**: an enemy in sight within 3 km, or the first shot received (artillery, aircraft, an ambush it could not see).
3. **It splits.** The unarmed vehicles (trucks…) leave **at once** to fall back, as their own group, named `<convoy> unarmed`. The armed vehicles stay in the convoy's group, which keeps its name.
4. **The armed vehicles fight or fall back.** Each vehicle has a combat value: tank 4, infantry fighting vehicle 3, armoured personnel carrier, AAA or other armed vehicle 1, unarmed 0. When the armed ones are worth at least 1.5 times the enemies in sight, they **close in** to 900 m of the nearest enemy, alarm red, weapons free; otherwise they fall back as well. An aircraft, or fire from beyond 3 km, cannot be fought: they fall back.
5. **When it falls back, it calls for help**, to its coalition, in the shape of a *troops in contact* call: its position (coordinates and MGRS), how many enemies and of what type, their bearing and distance. A **red smoke** marks the nearest enemy, a **green** one the convoy, renewed every 5 minutes while the contact lasts. When the mission can speak ([SRS configured](#srs-voice)), the same call goes out in voice on 243 and 121.5 MHz AM.
   Strong enough to fight, it asks for nothing: an information message gives the contact, how many enemies, their bearing and distance, with no smoke.
6. **It falls back behind cover**: toward the nearest friendly place (a campaign zone its side owns, one of its airbases), through a point terrain or a town hides from the enemy; when there is none, the shortest way out of range.
7. **After the contact.** A minute with nothing in sight and nothing received:
   - **after a fight**, it drives on by itself, by road rather than across country, and its unarmed vehicles join it;
   - **after a fall back**, it says so, stops and waits for an order: the enemy it fled is still there, and it does not drive back into the same ambush by itself.

A red convoy does exactly the same, on the red side.

### Which groups {#convoy-groups}

- **Every convoy spawned by `_spawn convoy`**, automatically. Its name is the one the spawn gives it (`[b]-Convoy-3`…); a part of it is enough in `_gc`, as with `groupname`.
  Beware: `-convoy` spawns a **red** convoy by default — a target. For a friendly one, add `side blue`: `-convoy, dest ALPHA, side blue`.
- A Mission Editor group listed in `mission.yaml` ([below](#configuration-missionyaml)).
- Any group, in game: `_gc <name>, convoy`, with the marker on the group (or with `groupname`).

### The orders {#convoy-orders}

| What you write | What it does |
|---|---|
| `_gc convoy-3, retreat` | falls back by road to the nearest friendly place |
| `_gc convoy-3, retreat KOBULETI` | falls back to this named point, or these coordinates |
| `_gc convoy-3, hold` | stops where it stands, both groups |
| `_gc convoy-3, resume` | drives on (by itself after a won fight): the armed vehicles take the road again, the unarmed ones join them, and the convoy becomes one group again within 300 m |
| `_gc convoy-3, status` | what the convoy is doing (driving, alerted, fighting, falling back, holding…) |
| `_gc supply, convoy, groupname Supply North` | hands the group `Supply North` to the convoy autopilot, under the name `supply` |

These are also the markers a game master sends to steer a convoy.

### Making the mission speak {#srs-voice}

The voice goes through SRS (`DCS-SR-ExternalAudio.exe`). VEAF reads its configuration from `Saved Games\DCS\DCS-SimpleRadio-Standalone\SRS_for_scripting_config.lua`, on the machine hosting the mission; without that file the call goes out as text only:

```lua
if not SERVER_CONFIG then SERVER_CONFIG = {} end
SERVER_CONFIG.SRS_DIRECTORY = "C:\\Program Files\\DCS-SimpleRadio-Standalone\\ExternalAudio"
SERVER_CONFIG.SRS_PORT = 5002
SERVER_CONFIG.SRS_EXECUTABLE = "DCS-SR-ExternalAudio.exe"
if not STTS then STTS = {} end
STTS.DIRECTORY = SERVER_CONFIG.SRS_DIRECTORY
STTS.SRS_PORT = SERVER_CONFIG.SRS_PORT
STTS.EXECUTABLE = SERVER_CONFIG.SRS_EXECUTABLE
```

`SRS_DIRECTORY` is the folder holding `DCS-SR-ExternalAudio.exe` (an `ExternalAudio` subfolder in recent SRS versions), `SRS_PORT` the SRS server's port.
The mission also needs `os`: a `MissionScripting.lua` that removes it, as DCS's own does, leaves the mission mute.

---

## The shipped aliases {#aliases}

`veafShortcuts` ships ready-made shortcuts, and they are how most pilots use this module:

| Alias | What it does |
|-------|--------------|
| `-ai_set` | `_gc` — attaches an autopilot to the nearest group; write its name after it |
| `-arty1`, `-arty2`, `-arty3` | Spawns a battery **and** attaches its autopilot, named `arty-1`, `arty-2`, `arty-3` |
| `-arty1_aim`, `-arty2_aim`, `-arty3_aim` | Ranging order to the matching battery |
| `-arty1_fire`, `-arty2_fire`, `-arty3_fire` | Fire-for-effect order to the matching battery |

Those firing aliases **deliberately end on `target` with no value**: you type the coordinates right
after, and they complete the order.

```
-arty1                          # the battery appears and its autopilot starts
-arty1_aim 42 N 42 E            # it ranges in on those coordinates
-arty1_fire                     # then fires in earnest, at the same target
```

---

## `mission.yaml` configuration {#configuration-missionyaml}

The module is enabled and disabled like the others:

```yaml
modules:
  GROUNDAI: true      # on by default; `false` removes the _gc marker and the convoy watch
```

Its one option is the list of Mission Editor groups to watch as convoys — `_spawn convoy` ones always are, with nothing to declare:

```yaml
modules:
  GROUNDAI:
    enabled: true
    convoys:
      - Supply North
      - Kutaisi Convoy
```

---

## Known limits {#limitations}

- **Two kinds of autopilot exist**: artillery and the convoy. The module is built to host others
  (`veafGroundAI.add` / `.remove` / `.get` take any named handler).
- **The convoy's watch does not see vegetation.** `land.isVisible` only accounts for terrain: the convoy may judge "in sight" an enemy that trees hide from DCS's AI. That is why its armed vehicles close in rather than halt: halted 1.9 km from an enemy "in sight", two Bradleys did not fire a round in two minutes (measured 2026-10-08).
- **Trees are no cover for the fall-back**: `world.searchObjects` does not find them. Only terrain and towns hide the rally point.
- **Smoke does not blind DCS's AI** (measured 2026-10-08): it marks, for the pilots. So the convoy lays no smoke screen.
- **A vehicle split off or merged back comes back whole**: DCS cannot recreate a unit with its damage. The watch almost always splits the convoy before the first hit.
- **The 250-metre search radius is not configurable.**
- Orders go through the F10 map only: **this module has no radio menu**.
- **A correction has no automatic spotter**: the pilot is the one who watches where the rounds land and calls the offset in. The module does not measure the miss
  itself.

---

## See also

- [veafShortcuts](veafShortcuts.en.md) — the full alias list, including `-ai_set` and the `-arty*` family
- [veafSecurity](veafSecurity.en.md) — what `KNOWN_PILOT` means, and how an unlisted pilot still gets through
- [veafSpawn](veafSpawn.en.md) — spawning the battery this module will drive
