# veafGroundAI — Driving an artillery battery from a marker

**Module ID:** `GROUNDAI` | **File:** `veafGroundAI.lua`

---

## Purpose

Gives a group of ground vehicles an **autopilot** that players command from the F10 map, with the
`_gc` marker. One kind of autopilot exists today: artillery (`ArtilleryUnitHandler`), told to
shell a set of coordinates — a few rounds to range in, then a fire-for-effect.

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

The module has **no configuration options**. It is enabled and disabled like the others:

```yaml
modules:
  GROUNDAI: true      # on by default; `false` removes the _gc marker
```

---

## Known limits {#limitations}

- **One kind of autopilot exists**: artillery. The module is built to host others
  (`veafGroundAI.add` / `.remove` / `.get` take any named handler), but no other one ships.
- **The 250-metre search radius is not configurable.**
- Orders go through the F10 map only: **this module has no radio menu**.
- **A correction has no automatic spotter**: the pilot is the one who watches where the rounds land and calls the offset in. The module does not measure the miss
  itself.

---

## See also

- [veafShortcuts](veafShortcuts.en.md) — the full alias list, including `-ai_set` and the `-arty*` family
- [veafSecurity](veafSecurity.en.md) — what `KNOWN_PILOT` means, and how an unlisted pilot still gets through
- [veafSpawn](veafSpawn.en.md) — spawning the battery this module will drive
