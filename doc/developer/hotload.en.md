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

The mission embeds a boot script holding the path of that folder **on the developer's machine**.
It loads hotload when the folder is there, and does nothing visible otherwise.

The same `.miz` therefore goes everywhere:

| Where the mission runs | What happens |
|---|---|
| Your machine, `io` and `lfs` unlocked | hotload starts, the **Hotload** F10 menu appears |
| Your machine, after a DCS update locked `io` and `lfs` again | hotload says so on screen: the unlock has to be done again |
| A server, a player, any other machine | one `HOTLOAD: not booted:` line in `dcs.log`, nothing on screen, the mission runs |

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

In the mission folder, create `src\scripts\hotload-boot.lua`, and replace the path on the first line of code with the one of **your** mission's `dcs-hotload` folder:

```lua
-- hotload-boot.lua: loads this mission's copy of dcs-hotload, https://github.com/MacFlorent/dcs-hotload
-- BASE_HOTLOAD_PATH is the mission's dcs-hotload folder on the developer's machine.
-- Where it is missing, as on a player's machine or a server, the mission writes one
-- "HOTLOAD: not booted:" line to dcs.log and runs on, with nothing on screen.
-- Empty it ([[]]) to build a copy that names no local folder.
local BASE_HOTLOAD_PATH = [[D:\Missions\my-mission\dcs-hotload]]

local f, err
if BASE_HOTLOAD_PATH == "" then
  err = "BASE_HOTLOAD_PATH is not set"
else
  f, err = loadfile(BASE_HOTLOAD_PATH .. [[\dcs-hotload.lua]])
end
if not f then
  env.info("HOTLOAD: not booted: " .. tostring(err))
else
  Hotload = Hotload or {}
  Hotload.root = BASE_HOTLOAD_PATH
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
The build embeds it in the `.miz` and generates its load trigger (see [`custom_scripts:`](../MISSION_YAML_REFERENCE.en.md#custom-scripts)).

What the script does:

- **it does not depend on `io` or `lfs`**: `loadfile` stays available in a mission, unlocked or not. On a machine without the folder it fails cleanly, and the script stops there;
- **it gives hotload its folder** (`Hotload.root`): hotload looks there for `user-f10\`, `user-lib\` and the mailbox;
- **it shields the mission from a hotload error**: if `dcs-hotload.lua` raises while starting, a `HOTLOAD: boot failed:` line goes to `dcs.log`, with no error window, and the rest of the mission loads.

The `HOTLOAD:` lines are the ones hotload itself writes: a `grep HOTLOAD` on `dcs.log` finds them all.

## Your machine's path is in the `.miz` {#local-path}

A mission does not know where it is on disk: the path is therefore hard-coded in the script, and the build copies it into the `.miz`.
The `.miz` you hand out therefore holds something like `D:\Missions\my-mission\dcs-hotload`.

It has **no effect** anywhere else: on another machine the folder does not exist, and the mission writes its `HOTLOAD: not booted:` line to `dcs.log`.
The only drawback is that the path, and so the names of your folders, can be read in the `.miz`.

For a `.miz` that names no folder, two ways:

- **empty the path** (`local BASE_HOTLOAD_PATH = [[]]`) and rebuild; the mission then writes `HOTLOAD: not booted: BASE_HOTLOAD_PATH is not set` to `dcs.log`, everywhere;
- **leave the script out** of the version you hand out, by declaring it only in a development [build profile](../MISSION_YAML_REFERENCE.en.md#profiles).

`hotload-setup.py boot-path --clear` does not help here: it only knows the trigger `patch-miz` adds.

## Checking with `status` {#status}

The setup script can tell what is missing:

```powershell
python dcs-hotload\bin\hotload-setup.py status --dcs "C:\Program Files\Eagle Dynamics\DCS World" --miz "build\my-mission.miz"
```

`--miz` is needed: the `.miz` VMCT builds is in `build\`, not next to `dcs-hotload\`.
On a mission set up as this page describes, the output looks like:

```text
hotload-setup: dcs-hotload 3.1.0 in D:\Missions\my-mission\dcs-hotload
hotload-setup: mailbox on
hotload-setup: MissionScripting.lua: unlocked
hotload-setup: my-mission.miz does not load dcs-hotload: run patch-miz
```

The first three lines are useful: the copy's version, the mailbox, the `io` and `lfs` unlock.
**The last one is wrong for us**: `status` only recognizes the trigger `patch-miz` adds and a `dofile` written with a literal path, not our boot script, which goes through a variable.
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

The boot script above, extracted as is from this page (only the path replaced with a test folder), was run with the Lua 5.1 interpreter shipped with DCS (`bin\luae.exe`), with mocked `env`, `trigger`, `timer`, `missionCommands` and `lfs`, against the real `dcs-hotload.lua` 3.1.0 and against a fake one that raises:

| Case | Expected and observed result |
|---|---|
| folder present, `io` and `lfs` unlocked | hotload starts, root = the mission's folder, **Hotload** menu created |
| folder absent | one `HOTLOAD: not booted:` line in the log, nothing on screen, no error |
| path emptied (`[[]]`) | one `HOTLOAD: not booted: BASE_HOTLOAD_PATH is not set` line, nothing on screen |
| `io` and `lfs` locked, folder absent (a player) | one `HOTLOAD: not booted:` line, nothing on screen, no error |
| `io` and `lfs` locked, folder present (your machine after an update) | hotload shows on screen that the unlock has to be done again |
| `dcs-hotload.lua` that raises | one `HOTLOAD: boot failed:` line in the log, nothing on screen, the mission load goes on |
| folder present without `user-f10\` | hotload starts and shows on screen that it cannot read `user-f10` |

`hotload-setup.py` 3.1.0 was run on a `.miz` built by VMCT (the demo mission), with this script added under `l10n/DEFAULT/`, where the build puts `custom_scripts`:

- `status --miz` answers `does not load dcs-hotload: run patch-miz` and exits with code 2, as described [above](#status);
- `boot-path --clear --miz` answers `has no BASE_HOTLOAD_PATH: run patch-miz`, exits with code 1 and leaves the `.miz` untouched.

It remains to see it run in DCS.
