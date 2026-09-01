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

Create an empty folder for your mission — this will be your Git repository. Download
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
.\veaf-tools.exe prepare --template minimal --theatre Caucasus
```

**What should happen**: twelve files are laid down, and the message ends with

> Mission folder ready: … Next: place/extract your .miz into src/mission, then `veaf-tools validate`
> and `veaf-tools build`.

`--theatre Caucasus` lays down a blank Caucasus mission in `src/mission`: you can build right away,
with no DCS round-trip. `--template minimal` picks the smallest module set; `standard` and `full`
turn on more.

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
```

Change the name, and **switch security off while you learn**:

```yaml
mission:
  name: My-First-Flight

security:
  disabled: true
```

Everything else in the file is commented out: those are examples ready to uncomment, not active
configuration.

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

**What should happen**: the build announces the generation of `veaf-config.lua`, the trigger
injection, then the pipeline steps. It ends with "Processing complete!".

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

This `.miz` has **no player slot** yet: do not try to fly it, that is what the next step is for.
What you have just checked is that the build chain works end to end, without launching DCS once.

---

## Step 5 — Add a player slot {#step-5-slot}

The blank mission has nobody in it. This is where DCS enters.

In the **DCS Mission Editor**, create a Caucasus mission with a flyable flight:

- an aircraft you own, blue coalition;
- **on the ramp, engines cold** — an air start makes the later checks awkward;
- skill **Client**.

Save it as `My-First-Flight.miz`, **in your mission folder**, then back to the console:

```powershell
.\veaf-tools.exe extract My-First-Flight.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build My-First-Flight.miz
```

`extract` replaces the blank `src/mission` with your real mission; `build` rebuilds it with the VEAF
scripts. This is the loop you will live in: **editor → `extract` → `build`**. It is repeatable as
often as you like — the build strips the VEAF triggers before injecting fresh ones, so nothing piles
up.

**How to tell**: `validate` no longer complains about the missing player slot.

!!! tip "Which file to reopen in the editor"
    Always the one at the **root** of the folder: that is the one the editor writes and the one the
    build rewrites. The variants under `missions/` are products — do not reopen those to edit.

---

## Step 6 — Fly it, and find the VEAF menu {#step-6-fly}

Launch `My-First-Flight.miz` in DCS, take the slot, and open the radio menu: **F10 "Other"**.

**What you should see**: a **VEAF** entry. It exists only because `RADIO: true` is in your
`mission.yaml`.

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

Open `src/presets.yaml`: it ships with a complete plan for the Caucasus. To see the mechanism,
replace it first with the smallest file that works:

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

You can then restore the shipped file (`git checkout src/presets.yaml`, or a fresh `prepare`): it
already carries the Caucasus airfields and the usual agency frequencies.

→ [card: radio presets](concepts/radio-presets.en.md)

---

## Step 8 — An objective players activate in game {#step-8-combat-zone}

This is the piece that makes a VEAF mission worth the trouble: an objective that only exists when
somebody asks for it.

**In the DCS editor**:

1. create a trigger zone named `CZ-Alpha`;
2. put a red vehicle group inside it, named `CZ-Alpha-ARMOR`.

**In `mission.yaml`**, uncomment the `COMBATZONE` block and cut it down to:

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: true
```

Then the usual loop:

```powershell
.\veaf-tools.exe extract My-First-Flight.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build My-First-Flight.miz
```

`validate` will tell you if `CZ-Alpha` does not exist in the mission — exactly the kind of mistake
it is there to catch.

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

**In the DCS editor**: give an airfield to the blue coalition. That is the only thing to do there —
the rest is written by the build.

`src/warehouses.yaml` is already correct as shipped:

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

Rebuild.

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
