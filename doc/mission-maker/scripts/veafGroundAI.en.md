# veafGroundAI — Driving an artillery battery from a marker

**Module ID:** `GROUNDAI` | **File:** `veafGroundAI.lua`

---

## Purpose

Gives a group of ground vehicles an **autopilot** that players command from the F10 map, with the
`_ground` marker. One kind of autopilot exists today: artillery (`ArtilleryUnitHandler`), told to
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

## The `_ground` marker {#marker-command}

A pilot drops a marker on the F10 map and writes its text. Seven verbs, and **`name` is mandatory
for all seven** — it names the autopilot, and it is the name you reuse to give it orders later.

| Verb | What it does |
|------|--------------|
| `_ground set` *(default)* | Attaches a named autopilot to a group and starts it. If the name already exists, the group is replaced. |
| `_ground unset` | Stops the autopilot and forgets it entirely. |
| `_ground order` | Gives the autopilot an order (see [order syntax](#order-syntax)). |
| `_ground start` | Restarts a stopped autopilot. |
| `_ground stop` | Stops it without forgetting it — its orders stay in memory. |
| `_ground clear` | Stops it **and** clears its orders. |
| `_ground status` | Prints on screen what the autopilot is currently doing. |

Writing `_ground` alone is the same as writing `_ground set`.

### Parameters

| Parameter | Verbs | Description |
|-----------|-------|-------------|
| `name` | **all** | The autopilot's name. **Mandatory**: a `_ground status, name` with no value is refused, not run with an empty name. |
| `groupname` | `set`, `unset` | Exact name of the DCS group to drive. |
| `order` | `order` | The order's text. |

**If you omit `groupname` on a `set`**, the module looks for the allied group **nearest the marker,
within 250 metres**. No group in that radius: the command **tells you** and does nothing. So drop the
marker on the battery, or name it.

### When nothing seems to happen {#silent-refusals}

None of these commands fails silently any more. They did, and an order that vanished without a word was
indistinguishable from a broken module.

| What you see | What it means |
|---|---|
| "No autopilot named *X*" | that name does not exist. **Reloading a mission discards the autopilots**: the `_ground set` has to be done again. The message reminds you of the command. |
| "No allied group within 250 m" | the marker is too far from the group, or the group belongs to the other coalition. Drop it on the group, or give `groupname`. |
| "unreadable order" | the order text could not be read at all. The message lists the valid orders. |
| "cannot aim, no target coordinates" | the order is fine, but `target` is missing or could not be read ([the accepted formats](#coordinate-formats)). |

```
_ground set, name arty-1, groupname ARTY-1
_ground status, name arty-1
_ground stop, name arty-1
```

---

## Order syntax {#order-syntax}

The text handed to `order` has **its own syntax, separated by semicolons** — not by commas like the
rest of the marker. That is this module's trap: an order written with commas is split by the marker
before it ever reaches the artillery.

| Order | Effect | Default rounds | Default radius |
|-------|--------|----------------|----------------|
| `aim` *(default)* | Ranging fire: a few rounds to adjust | 2 | 10 m |
| `fire` | Fire for effect | 40 | 100 m |
| `correct` | Shift the last aim point and fire again | 2 | 10 m |

| Order parameter | Description |
|-----------------|-------------|
| `target` | The target's coordinates ([the accepted formats](#coordinate-formats)). **Validated**: a string the module cannot read is ignored, and the order complains that it has no target. |
| `shells` | Number of rounds. Accepts a random range, e.g. `40-80`. |
| `radius` | Dispersion of the fire, in metres. Also accepts a range. |
| `correction` | The offset to apply, for the `correct` order: **three digits of true bearing then the distance in metres**. `09050` is 50 m east. **Validated**: an unreadable correction is refused and announced, never guessed. |

**`fire` with no `target` re-engages the last target aimed at** — which is what lets you chain a
ranging order and then the effect without re-entering the coordinates.

```
_ground order, name arty-1, order aim; radius 15-30; target 42 N 42 E
_ground order, name arty-1, order fire; radius 50-150; shells 40-80
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
_ground order, name arty-1, order aim; target 42 N 42 E
_ground order, name arty-1, order correct; correction 09050
_ground order, name arty-1, order fire; shells 40-80
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
| `-ai_set` | `_ground set` — attaches an autopilot to the nearest group |
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
  GROUNDAI: true      # on by default; `false` removes the _ground marker
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
