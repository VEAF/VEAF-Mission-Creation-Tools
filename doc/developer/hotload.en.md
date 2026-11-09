# Live scripts with dcs-hotload

[dcs-hotload](https://github.com/MacFlorent/dcs-hotload) runs Lua inside a DCS mission **while it runs**, without restarting it.
The script is read again from disk on every run: edit the file, run it again, see the result.
It runs two ways:

- **from the F10 menu**: every file in `user-f10/` becomes a menu command;
- **from a mailbox**: a `.lua` file saved into `user-inbox/` runs once, and its outcome is written to `user-outbox/`. An editor, a terminal or an agent can drive the mission that way.

It opens no network port: everything goes through files.
It is a third-party tool, written by Flogas; its full documentation is its [README](https://github.com/MacFlorent/dcs-hotload#readme).

This page explains how to load it in a mission built with VMCT, **without changing anything in VMCT**: a small boot script, declared in `custom_scripts`.

> ⚠️ **Recipe not tested in game yet.**
> The boot script was checked with DCS's own Lua interpreter (`luae.exe`) against a mocked `lfs` and `env`, in the five cases listed [below](#what-was-checked); it has not run in a real mission yet.
> Flogas is testing it; this page will be corrected from what he finds.

## The principle {#principle}

dcs-hotload is installed **once per machine**, in `Saved Games\DCS\Scripts\dcs-hotload\`.
The mission embeds a boot script that loads it **when it is there**, and does nothing otherwise.

So the same `.miz` goes everywhere:

| Where the mission runs | What happens |
|---|---|
| Your machine, hotload installed, `io` and `lfs` unlocked | hotload starts, the **Hotload** F10 menu appears |
| A server, a player, a machine without hotload | nothing, and no error message |
| A machine where `io` or `lfs` are still locked | nothing, and no error message |

Writing the machine's path straight into the mission sources (`dofile([[D:\...\dcs-hotload.lua]])`) only works on that machine: anywhere else, the `dofile` fails while the mission loads.

## Prerequisites {#prerequisites}

1. **Unlock `io` and `lfs`** in the DCS install's `Scripts\MissionScripting.lua`: comment out the lines `sanitizeModule('io')` and `sanitizeModule('lfs')`.
   DCS updates put the original file back: redo the edit after each one.

   > ⚠️ **This unlock applies to the whole DCS install, not to one mission.**
   > Once `io` and `lfs` are unlocked, **any mission** you load, including one downloaded from a multiplayer server, can read and write files on your disk.
   > That is the price of hotload, and of every tool that asks for the same edit.
   > Do it on a development machine, knowingly.

2. **Install dcs-hotload**: download `dcs-hotload-<version>.zip` from its [GitHub releases](https://github.com/MacFlorent/dcs-hotload/releases) and extract it into `Saved Games\DCS\Scripts\`. The archive holds a single `dcs-hotload\` folder, with `dcs-hotload.lua` inside.

   ```powershell
   Expand-Archive "$env:USERPROFILE\Downloads\dcs-hotload-3.0.0.zip" "$env:USERPROFILE\Saved Games\DCS\Scripts"
   ```

   If your DCS write folder is named `DCS.openbeta`, adapt the path.

3. **Create the `user-f10\` folder** next to `dcs-hotload.lua`: each `.lua` file in it becomes an F10 menu command.
   For the mailbox, also create `user-inbox\` and `user-outbox\` (see [hotload's README](https://github.com/MacFlorent/dcs-hotload#mailbox)).

## The boot script {#boot-script}

In the mission folder, create `src\scripts\hotload-boot.lua`:

```lua
-- hotload-boot.lua: loads dcs-hotload when this machine has it, otherwise does nothing.
-- One install per machine, in Saved Games\DCS\Scripts\dcs-hotload\.
-- true: user-f10\, user-lib\ and the mailbox live in missions\<sortie>\ under the install.
local PER_MISSION = false

if lfs and io then
  local install = lfs.writedir() .. [[Scripts\dcs-hotload]]
  local file = install .. [[\dcs-hotload.lua]]
  if lfs.attributes(file) then
    local root = install
    if PER_MISSION then
      local ok, sortie = pcall(function()
        return env.getValueDictByKey(env.mission.sortie)
      end)
      if ok and type(sortie) == "string" and sortie ~= "" then
        root = install .. [[\missions\]] .. (sortie:gsub("[^%w%-_]", "_"))
      end
    end
    Hotload = Hotload or {}
    Hotload.root = root
    local ok, err = pcall(dofile, file)
    if not ok then
      env.error("hotload-boot: " .. tostring(err))
    end
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

To embed it in a development variant only, put it in a [build profile](../MISSION_YAML_REFERENCE.en.md#profiles); this is not needed, since it does nothing where hotload is not installed.

## Load order {#load-order}

Mission scripts always load in this order: `veaf-config.lua` → `mission-script.lua` → the `custom_scripts`, in declaration order.
When the boot script runs, **the VEAF modules are already loaded and initialized**: a script run from hotload can call `veafSpawn`, `veafCombatZone` or any other module directly.

If `hotload-boot.lua` is declared after other `custom_scripts`, those are loaded too.

## One folder per mission {#per-mission-root}

By default, `user-f10\`, `user-lib\` and the mailbox are **shared by every mission**: they are the install folder's.

For a mission to have its own, set `PER_MISSION` to `true` in the boot script.
The root folder then becomes `Saved Games\DCS\Scripts\dcs-hotload\missions\<mission name>\`, where the name is the mission's `sortie` (the name typed in the Mission Editor), with every character other than a letter, a digit, `-` or `_` replaced by `_` (spaces included).
A mission without a `sortie` keeps the shared folder.

The folders are not created automatically: create `user-f10\` (and the mailbox, if needed) in that folder.
If it is missing, hotload says so on screen when the mission starts.

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

The boot script above, extracted as is from this page, was run with the Lua 5.1 interpreter shipped with DCS (`bin\luae.exe`), against a mocked `lfs` and `env` and a fake `dcs-hotload.lua`:

| Case | Expected and obtained |
|---|---|
| hotload installed | loaded, root = install folder |
| hotload installed, `PER_MISSION = true` | loaded, root = `missions\<sortie>` with special characters replaced |
| hotload absent | nothing, no error |
| `io` or `lfs` locked | nothing, no error |
| `dcs-hotload.lua` raising an error | a `hotload-boot:` line in the log, the mission keeps loading |

It still has to be seen running in DCS.
