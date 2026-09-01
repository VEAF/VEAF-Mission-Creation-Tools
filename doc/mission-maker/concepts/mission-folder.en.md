# The mission folder

## What it is {#what-it-is}

A version-controllable folder holding **everything**: the exploded DCS mission, your configuration,
your scripts, and the tools. It is your unit of work — the `.miz` is now just a build product.

## Creating it {#create-it}

> **The `.\` is required.** The default Windows terminal is PowerShell, which does not search the
> current directory — on purpose. `cmd.exe` accepts both forms, so `.\` works everywhere. See
> [PowerShell or Command Prompt?](../GUIDE.en.md#powershell-vs-cmd).

```powershell
.\veaf-tools.exe prepare --template minimal --theatre Caucasus
```

Twelve files appear:

```
my-mission/
├── mission.yaml                     # the build configuration
├── src/
│   ├── mission/                     # the exploded DCS mission (extract writes here)
│   ├── options                      # the DCS options table injected into the .miz
│   ├── scripts/
│   │   ├── mission-script.lua       # your Lua
│   │   └── veafDynamicConfig.lua    # dynamic loading (dev/test)
│   ├── presets.yaml                 # radio presets
│   ├── waypoints.yaml               # named flight plans
│   ├── spawnables.yaml              # spawnable aircraft groups
│   ├── dynamic-slot-templates.yaml  # dynamic-slot templates
│   ├── warehouses.yaml              # stock and dynamic slots per airfield
│   ├── spawn-groups.yaml            # ground/sea groups for `_spawn`
│   └── versions.yaml                # weather/time variants
├── published/                       # VEAF scripts and tools (laid down by the updater)
└── .gitignore
```

`--theatre` lays down a synthetic blank mission in `src/mission`: the folder builds with no DCS
round-trip. Without it, `src/mission` stays empty and you must extract a `.miz` into it.

`--template` picks the module set of the generated `mission.yaml`: `minimal`, `standard`, `full`, or
`custom` (interactive). With no `--template`, the shipped default `mission.yaml` is copied as-is.
Whatever the tier, the five *opt-out* community scripts (`STTS`, `CTLD`, `AIEN`, `CSAR`, `SKYNET`)
are written out explicitly as `true` or `false`: leaving them out would enable them (see
[the `mission.yaml` gotcha](mission-yaml.en.md#gotcha)).

## Filling it from an existing `.miz` {#from-a-miz}

```powershell
.\veaf-tools.exe extract my-mission.miz
```

The `.miz` is exploded into `src/mission/`. The round trip is **repeatable**: opening the built
`.miz` in the DCS editor, saving, re-extracting and rebuilding does not duplicate the VEAF triggers
— the build strips them before injecting them again.

## The gotcha {#gotcha}

**The produced `.miz` and the scripts are resolved from the current directory, not from the
argument.** Always run `.\veaf-tools.exe` **from** the mission folder; run from elsewhere with the
folder as an argument, it looks for `published/` in the wrong place and writes the `.miz` beside
itself.

And `.gitignore` is **never** overwritten, not even with `--force`: it is yours.

## Going further {#more}

- [Full guide — creating a new mission](../GUIDE.en.md)
- [CLI reference — `prepare`](../../CLI_REFERENCE.en.md#prepare) and [`extract`](../../CLI_REFERENCE.en.md#extract)
