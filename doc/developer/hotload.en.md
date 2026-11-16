# Live scripts with dcs-hotload

[dcs-hotload](https://github.com/MacFlorent/dcs-hotload) runs Lua inside a DCS mission **while it runs**, without restarting it.
The script is read again from disk on every run: edit the file, run it again, see the result.
It runs two ways:

- **from the F10 menu**: every file in `user-f10/` becomes a menu command;
- **from a mailbox**: a `.lua` file saved into `user-inbox/` runs once, and its outcome is written to `user-outbox/`. An editor, a terminal or an agent can drive the mission that way.

It opens no network port: everything goes through files.
It is a third-party tool, written by Flogas; its full documentation is its [README](https://github.com/MacFlorent/dcs-hotload#readme).

This page explains how to load it in a mission built with VMCT, **without changing anything in VMCT**, following hotload's own model: one copy of hotload **per mission**, in the mission folder, loaded by a small boot script declared in `custom_scripts`.

> ⚠️ **Recipe not tested in game yet.**
> The boot script was checked with DCS's Lua interpreter (`luae.exe`), in the cases described [below](#what-was-checked); it has not run in a real mission yet.

## The principle {#principle}

Each mission has **its own** copy of hotload, in a `dcs-hotload\` folder next to its `mission.yaml`.
Its F10 commands, its libraries and its mailbox live in that copy: two missions share nothing.

hotload is only for a **dynamic build** (`--dynamic-mode`, or `build.dynamic_loading: true` in `mission.yaml`, see [`build:`](../MISSION_YAML_REFERENCE.en.md#build)).
In a dynamic build, VMCT gives the mission the path of its folder on the machine that built it, in the `VEAF_DYNAMIC_MISSIONPATH` variable, and the mission reads its scripts from disk.
The boot script uses it to find `dcs-hotload\`: there is no path to write by hand.

| How the mission is built and where it runs | What happens |
|---|---|
| Dynamic build, on your machine, `io` and `lfs` unlocked | hotload starts, the **Hotload** F10 menu appears |
| Dynamic build, on your machine, after a DCS update locked `io` and `lfs` again | hotload says so on screen: the unlock has to be done again |
| Static build, anywhere (server, player, your machine) | one `HOTLOAD: not booted:` line in `dcs.log`, nothing on screen, the mission runs |

The script can therefore stay declared in the mission for good: there is no build profile to set up, and nothing to remove before handing out a static build.

Why a boot script rather than the trigger `hotload-setup.py patch-miz` adds: VMCT **regenerates** the `.miz` on every build, and a trigger added to the `.miz` would be gone after the next build.
The boot script lives in the mission's sources instead.
It does what hotload's trigger does, and reuses its code.

## Installing hotload in the mission {#install}

1. **Download** `dcs-hotload-<version>.zip` from hotload's [GitHub releases](https://github.com/MacFlorent/dcs-hotload/releases).

2. **Extract it into the mission folder**, the one holding `mission.yaml`. The archive holds a single `dcs-hotload\` folder, with `dcs-hotload.lua` inside:

   ```powershell
   cd "D:\Missions\my-mission"
   Expand-Archive "$env:USERPROFILE\Downloads\dcs-hotload-3.1.0.zip" .
   ```

   This gives:

   ```text
   my-mission\
     mission.yaml
     src\
     build\
     dcs-hotload\
       dcs-hotload.lua
       bin\
   ```

3. **Create `dcs-hotload\user-f10\`**: every `.lua` file in it becomes an F10 menu command.
   The archive does not hold it, and without it hotload shows an error when the mission starts.
   For the mailbox, also create `dcs-hotload\user-inbox\` and `dcs-hotload\user-outbox\` (see [hotload's README](https://github.com/MacFlorent/dcs-hotload#mailbox)); create `user-lib\` when you need it.

   ```powershell
   New-Item -ItemType Directory dcs-hotload\user-f10, dcs-hotload\user-inbox, dcs-hotload\user-outbox
   ```

The `dcs-hotload\` folder is part of the mission's sources: your F10 commands and your libraries live in it, and it can go into the mission's git repository.

## Unlocking `io` and `lfs` {#unlock}

hotload reads and writes files: it needs `io` and `lfs`, which DCS takes away from missions by default.
hotload's setup script does the unlock; it needs Python 3.8 or later, and nothing else:

```powershell
python dcs-hotload\bin\hotload-setup.py unlock --dcs "C:\Program Files\Eagle Dynamics\DCS World"
```

`--dcs` is the DCS install folder, the one holding `Scripts\MissionScripting.lua`: nothing guesses it.
The script comments out the `sanitizeModule('io')` and `sanitizeModule('lfs')` lines of that file and keeps the original as `MissionScripting.lua.bak`.
If the install is under `C:\Program Files`, run PowerShell as administrator.
By hand, it is the same edit: comment out those two lines.

DCS updates put the original file back: the edit has to be redone after each one, and hotload says so on screen when it is missing.

> ⚠️ **This unlock applies to the whole DCS install, not to one mission.**
> Once `io` and `lfs` are unlocked, **any mission** you load, including a mission downloaded from a multiplayer server, can read and write files on your disk.
> It also affects multiplayer integrity checks.
> That is the price of hotload, and of every tool that asks for the same edit.
> Do it on a development machine, knowingly.

## The boot script {#boot-script}

In the mission folder, create `src\scripts\hotload-boot.lua`; it is the same for every mission:

```lua
-- hotload-boot.lua: loads the mission's copy of dcs-hotload, https://github.com/MacFlorent/dcs-hotload
-- Only a dynamic build sets VEAF_DYNAMIC_MISSIONPATH, to the mission folder on the machine that
-- built it; the copy is its dcs-hotload folder. In a static build, or where that folder is
-- missing, the mission writes one "HOTLOAD: not booted:" line to dcs.log and runs on, with
-- nothing on screen.
local root, f, err
if type(VEAF_DYNAMIC_MISSIONPATH) ~= "string" or VEAF_DYNAMIC_MISSIONPATH == "" then
  err = "VEAF_DYNAMIC_MISSIONPATH is not set (not a dynamic build)"
else
  root = VEAF_DYNAMIC_MISSIONPATH:gsub("[\\/]+$", "") .. "/dcs-hotload"
  f, err = loadfile(root .. "/dcs-hotload.lua")
end
if not f then
  env.info("HOTLOAD: not booted: " .. tostring(err))
else
  Hotload = Hotload or {}
  Hotload.root = root
  local ok, crash = pcall(f)
  if not ok then
    env.error("HOTLOAD: boot failed: " .. tostring(crash))
  end
end
```

Then declare it in `mission.yaml`:

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/hotload-boot.lua
```

If the mission already has `custom_scripts`, add the line to the existing list.
The build generates its loading (see [`custom_scripts:`](../MISSION_YAML_REFERENCE.en.md#custom-scripts)): in a dynamic build it is read from disk like the other mission scripts.

What the script does:

- **it does nothing outside a dynamic build**: in a static build, `VEAF_DYNAMIC_MISSIONPATH` is not set;
- **it takes the path in any form**: with or without a trailing separator, `/` or `\`;
- **it does not depend on `io` or `lfs`**: `loadfile` stays available in a mission, unlocked or not. If the `dcs-hotload\` folder is missing, it fails cleanly and the script stops there;
- **it gives hotload its folder** (`Hotload.root`): hotload looks there for `user-f10\`, `user-lib\` and the mailbox;
- **it shields the mission from a hotload error**: if `dcs-hotload.lua` raises while starting, a `HOTLOAD: boot failed:` line goes to `dcs.log`, with no error window, and the rest of the mission loads.

The `HOTLOAD:` lines are the ones hotload itself writes: a `grep HOTLOAD` on `dcs.log` finds them all.

`VEAF_DYNAMIC_MISSIONPATH` is the folder the build writes the `.miz` to.
By default it is the mission folder; if you give the build a `.miz` path elsewhere, it is that folder, and VMCT's dynamic loading also looks there for `src\scripts\`.

## Checking with `status` {#status}

The setup script can tell what is missing:

```powershell
python dcs-hotload\bin\hotload-setup.py status --dcs "C:\Program Files\Eagle Dynamics\DCS World" --miz "my-mission_20261111.miz"
```

`--miz` is needed as soon as the folder holds several `.miz`, which happens fast: the build dates them (`<name>_<date>.miz`).
On a mission set up as this page describes, the output looks like:

```text
hotload-setup: dcs-hotload 3.1.0 in D:\Missions\my-mission\dcs-hotload
hotload-setup: mailbox on
hotload-setup: MissionScripting.lua: unlocked
hotload-setup: my-mission_20261111.miz does not load dcs-hotload: run patch-miz
```

The first three lines are useful: the copy's version, the mailbox, the `io` and `lfs` unlock.
**The last one is wrong for us**: `status` only recognizes the trigger `patch-miz` adds and a `dofile` written with a literal path, not our boot script, which starts from `VEAF_DYNAMIC_MISSIONPATH`.
It therefore concludes that the mission does not load hotload, and exits with code 2.
**Do not run `patch-miz`**: it would add a second load to the `.miz`, which the next build would erase anyway.

To know whether the mission really loads hotload, the surest way is to start it: the `dcs-hotload 3.1.0 ready` message on screen, and `HOTLOAD: ready` in `dcs.log`, with the root folder.

## Load order {#load-order}

Mission scripts always load in this order: `veaf-config.lua` → `mission-script.lua` → the `custom_scripts`, in declaration order.
When the boot script runs, **the VEAF modules are already loaded and initialized**: a script run from hotload can call `veafSpawn`, `veafCombatZone` or any other module directly.

If `hotload-boot.lua` is declared after other `custom_scripts`, those are loaded too.

## Two reservations {#caveats}

**The F10 menu has ten places at its root.**
DCS shows only ten entries per level of the F10 menu, and hotload adds its own, **Hotload**, at the root.
A VEAF mission already puts its own menus there: we have not counted how many yet, and if the root is full, an entry will disappear.
To be checked in game.

**VEAF modules are not reloaded with hotload.**
[hotload's README](https://github.com/MacFlorent/dcs-hotload#libraries-in-user-lib) forbids it itself: code that owns live objects is not reloaded.
VEAF modules own radio menus, scheduled tasks and registered zones; reloading them would replace their functions under objects already created.
hotload is for **driving and testing** a VEAF mission live: spawning a group, querying a zone's state, trying a piece of mission script.
To test a change to a VEAF module, use the [developer mode](GUIDE.en.md#developer-mode) and a mission restart.

## What was checked {#what-was-checked}

The boot script above, extracted as is from this page, was run with the Lua 5.1 interpreter shipped with DCS (`bin\luae.exe`), with mocked `env`, `trigger`, `timer`, `missionCommands` and `lfs`, against the real `dcs-hotload.lua` 3.1.0 and against a fake one that raises:

| Case | Expected and observed result |
|---|---|
| `VEAF_DYNAMIC_MISSIONPATH` ending with `/`, with `\`, or with no separator | hotload starts, root = `<mission folder>/dcs-hotload`, **Hotload** menu created |
| `VEAF_DYNAMIC_MISSIONPATH` not set (static build) | one `HOTLOAD: not booted:` line in the log, nothing on screen, no error |
| `VEAF_DYNAMIC_MISSIONPATH` empty | one `HOTLOAD: not booted:` line, nothing on screen |
| dynamic build without a `dcs-hotload\` folder | one `HOTLOAD: not booted:` line, nothing on screen, no error |
| `io` and `lfs` locked, static build (a player) | one `HOTLOAD: not booted:` line, nothing on screen, no error |
| `io` and `lfs` locked, dynamic build (your machine after an update) | hotload shows on screen that the unlock has to be done again |
| `dcs-hotload.lua` that raises | one `HOTLOAD: boot failed:` line in the log, nothing on screen, the mission load goes on |
| folder present without `user-f10\` | hotload starts and shows on screen that it cannot read `user-f10` |

On the build side, VMCT's code was read: the trigger that sets `VEAF_DYNAMIC_MISSIONPATH` has the condition `return false` in a static build, and a default build of a test mission does carry that condition.

`hotload-setup.py status` 3.1.0 was run on a `.miz` built by VMCT (the demo mission), with this script added under `l10n/DEFAULT/`, where the build puts `custom_scripts`: it answers `does not load dcs-hotload: run patch-miz` and exits with code 2, as described [above](#status).

It remains to see it run in DCS.
