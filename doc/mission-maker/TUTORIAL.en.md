# Tutorial — your first mission

One thread, from an empty folder to a mission that runs. You know the DCS Mission Editor; you have
never opened VMCT.

Every step says **what to type**, **what should happen**, and **how to tell it worked**. The
background is not here: each concept links to [its card](concepts/README.en.md) at the moment it is
needed. If you want the overview first, read
[Discover VMCT in ten minutes](DISCOVER.en.md).

Allow an hour, half of it inside DCS.

---

## Step 0 — Install the tools {#step-0-install}

Create an empty folder for your mission. Download
`veaf-tools-updater.exe` from the
[latest release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest),
drop it in, and run it:

```powershell
.\veaf-tools-updater.exe
```

> **The `.\` is not decoration.** The default Windows terminal is **PowerShell**, and PowerShell
> does not search the current directory — on purpose, so that an executable dropped there cannot
> take the place of a real command. Without the `.\`, it answers that `veaf-tools-updater.exe` "is
> not recognized", naming the very file you are looking at. Command Prompt (`cmd.exe`) accepts both
> forms, so `.\` works everywhere: it is the form this documentation writes throughout. Details and
> the other differences between the two shells:
> [PowerShell or Command Prompt?](GUIDE.en.md#powershell-vs-cmd).

> Windows sometimes blocks a downloaded `.exe`: right-click → **Properties** → tick **Unblock**.

**What should happen**: a `published/` folder appears, and `veaf-tools.exe` next to the updater.

**How to tell**:

```powershell
.\veaf-tools.exe about
```

prints the installed version.

---

## Step 1 — Create the mission folder {#step-1-prepare}

```powershell
.\veaf-tools.exe prepare --template standard --theatre Caucasus
```

**What should happen**: twelve files are laid down, plus `ctld-config.yaml`, and the message ends
with

> Mission folder ready: … Next: place/extract your .miz into src/mission, then `veaf-tools validate`
> and `veaf-tools build`.

`--theatre Caucasus` lays down a blank Caucasus mission in `src/mission`: you can build right away,
with no DCS round-trip.

`--template standard` picks this tutorial's module set: the modules you will need are already
written into `mission.yaml`, the ones that require configuration being shipped **commented out**,
ready to enable. `minimal` lays down fewer — too few for step 8, where you would have a block to
write from scratch; `full` lays down more.

!!! note "Re-running `prepare` later"
    On a folder that is already prepared, `prepare` asks file by file whether to **replace** or
    **keep** — with a "replace all" and a "keep all". Answer *keep* for `mission.yaml`: it is the
    file you edit by hand, and the only one whose content is yours. The template is then not
    applied, and the tool says so.

**How to tell**: `src/mission/mission` exists, and `mission.yaml` is at the root.

→ [card: the mission folder](concepts/mission-folder.en.md)

---

## Step 2 — Look at what was generated {#step-2-look}

Open `mission.yaml`. The substance is two blocks:

```yaml
mission:
  name: "My-Mission"

modules:
  # ── Infrastructure ──
  UNITS:
  TIME:
  CACHE:
  EVENTS:
  MARKERS:
  COMMANDS:
  # ── Core ──
  RADIO: true  # the VEAF F10 radio menu
  SPAWN: true
  SHORTCUTS: true  # built-in aliases (-shilka, -sa2, …)
  INTERPRETER: true
  # ── Features ──
  NAMEDPOINTS: true
  MOVE: true
  GRASS: true
  WEATHER: true
  REMOTE: true
  AIRBASES: true
  # ── Combat ──
  GROUNDAI: true  # ground units AI behaviour (required by CASMISSION)
  CASMISSION: true  # `_cas` marker (no config)
  TRANSPORTMISSION: true  # `_transport` marker (no config)
  CARRIER: true  # carrier-operations radio menus
  #   COMBATZONE:
  #     enabled: true
  #     combat_zones:
  #       - type: zone
  #         zone_name: CZ-Alpha
  #         friendly_name: Alpha Zone
  #         training: false
```

(A commented `QRA` block and a `# ── Community ──` section follow — step 8 and step 6 come back to
those.)

Three forms of module live side by side, and the difference matters:

| Form | What it means |
|---|---|
| `UNITS:` — nothing after the colon | infrastructure, always there, nothing to configure |
| `RADIO: true` | a switch: the module works as it is |
| `#   COMBATZONE:` — a commented block | the module needs configuration; the example is ready to uncomment |

Change the name, and **switch security off while you learn**:

```yaml
mission:
  name: My-First-Flight

security:
  disabled: true
```

Then, **if you have no SRS server**, switch text to speech off right away: find the `STTS: true`
line under `# ── Community ──` and set it to `false`.

```yaml
  STTS: false
```

Without SRS, STTS has nothing to do — no reason to have it on while you learn. If you do not know
what SRS is, you do not have it: set `false`.

The rest of the file — section headers, `mission:` options, blocks for modules that need
configuration — is commented out: those are examples ready to uncomment, not active configuration.

!!! warning "`security: disabled: true` is not optional here"
    VEAF security is **on** by default: most marker commands and combat-zone activations then need
    an authenticated radio or a password. Offline, on your own, that shows up as commands doing
    nothing — and you go looking for the bug elsewhere. The `security:` block goes at the **root** of
    the file, not inside `modules:`. Put it back before you deploy on a server.

→ [card: `mission.yaml` and its modules](concepts/mission-yaml.en.md) ·
[veafSecurity](scripts/veafSecurity.en.md)

---

## Step 3 — Check before building {#step-3-validate}

```powershell
.\veaf-tools.exe validate
```

**What should happen**: three warnings, zero errors.

> ⚠ No player slot in the mission (no unit with Client or Player skill)…
> ⚠ presets.yaml is configured but the mission has no player aircraft…
> ⚠ waypoints.yaml is configured but the mission has no aircraft group…
> Validation: 0 errors, 3 warnings.

That is expected: the mission is empty. The warnings describe exactly what you are about to add.

---

## Step 4 — Build {#step-4-build}

```powershell
.\veaf-tools.exe build My-First-Flight.miz
```

**What should happen**: the build announces the generation of `veaf-config.lua`, **the list of
modules it read**, the trigger injection, then the pipeline steps. It ends with "Processing
complete!".

> Active VEAF modules (22): AIRBASES, CACHE, CARRIER, CASMISSION, COMMANDS, CSAR, CTLD, EVENTS,
> GRASS, GROUNDAI, INTERPRETER, MARKERS, MOVE, NAMEDPOINTS, RADIO, REMOTE, SHORTCUTS, SPAWN, TIME,
> TRANSPORTMISSION, UNITS, WEATHER

That line is your acknowledgement of receipt: a module you have just added and which is not on it
was not read. Modules that carry a list show how many entries they hold — you will see
`COMBATZONE (1)` appear at step 8.

The total depends on what you switched off: 22 here because `STTS` went to `false` at step 2, 23 if
you left it on.

**How to tell**: **two** files appeared.

| File | What it is |
|---|---|
| `My-First-Flight.miz` | the base mission |
| `missions/My-First-Flight_noon.miz` | the "noon" variant, produced by `src/versions.yaml` |

Not a duplicate: the weather step found its configuration file.

→ [card: the build](concepts/build.en.md) · [card: weather variants](concepts/weather-variants.en.md)

!!! warning "Run `veaf-tools.exe` from the mission folder"
    The scripts and the output file are resolved from the current directory. Run from elsewhere and
    it looks for `published/` in the wrong place.

!!! tip "Always spell out the `.miz`"
    The name you give is kept **only** if it ends in `.miz`. `build My-First-Flight` — no extension
    — and a bare `build` both write `My-First-Flight_YYYYMMDD.miz`, with today's date. Handy for
    archiving a version, confusing during the tutorial: you would go looking for "the one at the
    root" and not recognise it. Details: [card: the build](concepts/build.en.md).

This `.miz` has **no player slot** yet: do not try to fly it, that is what the next step is for.
What you have just checked is that the build chain works end to end, without launching DCS once.

---

## Step 5 — Add a player slot {#step-5-slot}

The blank mission has nobody in it. This is where DCS enters.

**Do not create a new mission**: open the one you have just built. In the **DCS Mission Editor**,
open `My-First-Flight.miz`, at the root of your mission folder, and add a flyable flight to it:

- an aircraft you own, blue coalition;
- **on the ramp, engines cold** — an air start makes the later checks awkward;
- skill **Client**.

Save it (same name, same place), then back to the console:

```powershell
.\veaf-tools.exe extract My-First-Flight.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build My-First-Flight.miz
```

`extract` replaces the blank `src/mission` with your real mission; `build` rebuilds it with the VEAF
scripts. This is the loop you will live in: **editor → `extract` → `build`**. It is repeatable as
often as you like — the build strips the VEAF triggers before injecting fresh ones, so nothing piles
up. That is why you reopen the built `.miz` rather than making another one: your editor work and the
build's work stack up without treading on each other.

**How to tell**: `validate` no longer complains about the missing player slot.

!!! tip "Which file to reopen in the editor"
    Always the one at the **root** of the folder: that is the one the editor writes and the one the
    build rewrites. The variants under `missions/` are products — do not reopen those to edit.

---

## Step 6 — Fly it, and find the VEAF menu {#step-6-fly}

Launch `My-First-Flight.miz` in DCS, take the slot, and open the radio menu: **F10 "Other"**.

**What you should see**: a **VEAF** entry. It exists only because `RADIO: true` is in your
`mission.yaml`.

The menu holds more than that — the `standard` template also turns on CTLD (helicopter logistics and
transport) and CSAR (downed-pilot recovery). This tutorial uses the VEAF entry alone; you can switch
the others off the way you did STTS at step 2, by setting their line to `false` in `mission.yaml`.

Then try a marker: drop a marker on the F10 map and give it the alias

```
-shilka
```

A ZSU-23-4 Shilka appears where the marker is. That is `SPAWN: true` plus `SHORTCUTS: true` — and
the security you switched off at step 2. The long form of the same command is
`_spawn unit, name ZSU-23-4 Shilka`.

**If the VEAF menu is not there**: the scripts did not load. The DCS log says so — see
[reading the DCS logs](LOGS.en.md).

→ [marker aliases](../ALIASES.en.md) · [veafSpawn](scripts/veafSpawn.en.md)

---

## Step 7 — Give everyone the same radios {#step-7-presets}

Open `src/presets.yaml`: it ships with a complete plan for the Caucasus. To see the mechanism you
are going to replace it with the smallest file that works — so **put it aside first**:

```powershell
Copy-Item src\presets.yaml src\presets.yaml.bak
```

Then replace its content with:

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

Rebuild, and reopen the mission in game.

**How to tell**: channel 1 of your aircraft's first radio is on 243.0, and a "presets" kneeboard is
available in the cockpit.

Now restore the shipped file — it already carries the Caucasus airfields and the usual agency
frequencies, and it is the one you will want to work with:

```powershell
Copy-Item src\presets.yaml.bak src\presets.yaml -Force
```

!!! note "How real projects do this"
    Copying a file before changing it works, but it does not scale: after a few weeks a mission is
    a dozen files that evolve together, and "go back to the day before yesterday" becomes
    impossible by hand. **Version control** tools answer exactly that: they keep the folder's full
    history, let you compare any two states and return to any of them, and make working as a team
    possible.

    The de facto standard is called **Git**. You do not need it to finish this tutorial, and it is
    a tool in its own right that has to be learned for itself — but the moment your mission matters,
    it is the next investment that pays. To start:
    [Pro Git](https://git-scm.com/book/en/v2), free and complete.

→ [card: radio presets](concepts/radio-presets.en.md)

---

## Step 8 — An objective players activate in game {#step-8-combat-zone}

This is the piece that makes a VEAF mission worth the trouble: an objective that only exists when
somebody asks for it.

**In the DCS editor**:

1. create a trigger zone named `CZ-Alpha`;
2. put a red vehicle group inside it, named `CZ-Alpha-ARMOR`.

**In `mission.yaml`**, find the `COMBATZONE` block under the `# ── Combat ──` heading. It ships
commented out, with the right example already in it:

```yaml
  #   COMBATZONE:
  #     enabled: true
  #     combat_zones:
  #       - type: zone
  #         zone_name: CZ-Alpha
  #         friendly_name: Alpha Zone
  #         training: false
```

Uncomment it, then set `training` to `true`:

```yaml
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: true
```

!!! warning "Uncommenting means removing the `#` **and the three spaces after it**"
    On each line of the block, delete exactly `#` plus three spaces — never the spaces at the start
    of the line. In YAML the indentation *is* the structure: `  COMBATZONE:` at two spaces belongs
    to `modules:`, at zero spaces it becomes a top-level block nothing reads. That is why the
    shipped block is indented the way it is: the subtraction comes out right.

Then the usual loop:

```powershell
.\veaf-tools.exe extract My-First-Flight.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build My-First-Flight.miz
```

`validate` will tell you if `CZ-Alpha` does not exist in the mission — exactly the kind of mistake
it is there to catch.

**How to tell, before launching DCS**: two signs, in this order.

1. `validate` reports **0 errors**: the zone you named really is in the mission.
2. The build lists your active modules, and `COMBATZONE` now carries its zone count:

> Active VEAF modules (23): AIRBASES, CACHE, CARRIER, CASMISSION, **COMBATZONE (1)**, COMMANDS, …

If you read `COMBATZONE (0)`, the module is active but your `combat_zones:` list came to nothing —
an indentation mistake, almost always. If `COMBATZONE` does not appear at all, the block is not
inside `modules:`.

**In game**: the zone is **empty** at start-up, on purpose. Go to
**F10 "Other" → COMBAT ZONES → Alpha Zone → Activate zone**.

**What you should see**: the message "VeafCombatZone Alpha Zone has been activated.", then your
armour appearing, then the zone report.

!!! danger "The gotcha that costs an hour"
    A group is only captured by the zone if **its name starts with the zone's name**. Placed in the
    right spot but named `ARMOR-1`, it is ignored. It must be `CZ-Alpha-ARMOR-1`.

→ [card: combat zones](concepts/combat-zones.en.md)

---

## Step 9 — Open an airfield to dynamic slots {#step-9-dynamic-slots}

This step is often **already done**, and that is normal: by placing your blue aircraft on an
airfield's ramp at step 5, you gave that airfield to the blue coalition. Check it in the DCS editor
and change nothing if that is the case — it is the only thing to do there, the rest is written by
the build.

`src/warehouses.yaml` does not need touching either: as shipped, it enables dynamic slots on
**every** airfield belonging to a coalition. Under its comments, it comes down to two blocks:

```yaml
blue:
  defaults:
    fuel: unlimited
    weapons: unlimited

red:
  defaults:
    fuel: unlimited
    weapons: unlimited
```

If you changed something in the editor, run `extract` then `build` again. If everything was
already in place, there is nothing to rebuild: go straight to the check.

**How to tell**: in DCS, at slot selection, the airfield offers dynamic-spawn aircraft.

**If the list is shorter than expected**: DCS only offers what the airfield's parking can actually
take. An airfield with helicopter-only spots will not offer aircraft, whatever the stock says.

→ [card: dynamic slots](concepts/dynamic-slots.en.md)

---

## Step 10 — What next {#step-10-next}

You have a mission that runs, versioned, rebuildable. The rest is à la carte:

| You want to | Go to |
|---|---|
| Understand one piece in particular | [the cards](concepts/README.en.md) |
| Add managed tankers, AWACS, carriers | [veafAssets](scripts/veafAssets.en.md) |
| A QRA that scrambles on intrusion | [veafQraManager](scripts/veafQraManager.en.md) |
| Air combat by waves | [veafAirWaves](scripts/veafAirWaves.en.md) |
| Password-protect your server | [veafSecurity](scripts/veafSecurity.en.md) |
| Every configuration option | [`mission.yaml` reference](../MISSION_YAML_REFERENCE.en.md) |
| Every command | [CLI reference](../CLI_REFERENCE.en.md) |
| The end-to-end detail | [Full guide](GUIDE.en.md) |

And keep the habit: `validate` before `build`, and [the DCS log](LOGS.en.md) whenever something
fails to load.
