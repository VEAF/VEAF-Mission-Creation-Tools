# Custom scripts

## What it is {#what-it-is}

The Lua that cannot be described in YAML. It lives in the mission folder's `src/scripts/`, and the
build embeds it in the `.miz`.

Two cases:

- **`src/scripts/mission-script.lua`** — shipped with the folder, loaded automatically, right after
  `veaf-config.lua`. Most of your code goes here: custom aliases, helper functions, Lua settings for
  third-party scripts.
- **Your other `.lua` files** — declare them under `custom_scripts:` when you want control over the
  order or the moment they load.

## The smallest example that works {#minimal-example}

Nothing to write in `mission.yaml`: drop your code into `src/scripts/mission-script.lua` and
rebuild.

```lua
-- src/scripts/mission-script.lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-myalias")
    :setDescription("My custom spawn")
    :setVeafCommand("_spawn group, name my-custom-group")
)
```

`-myalias` then works as an F10 map marker, just like the built-in aliases.

For an extra file:

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/MyTooling.lua
```

## Delaying a load {#delay}

A script that inventories the world at start-up must run **after** the ones that create groups:

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/MyTooling.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12
```

`delay_seconds` takes the script out of the shared trigger and gives it one of its own, armed twelve
seconds in.

## The gotcha {#gotcha}

**The delay decides the order, not the position in the list.** A script with no delay goes at
start-up whatever its rank; a delayed one goes at its time. Declaring a delayed script before an
immediate one produces a build warning, because reading the list suggests the opposite of what will
happen.

And `generate_load_trigger: false` does not exclude the file from the `.miz` — it embeds it
**without** loading it. It is up to your `mission-script.lua` to `dofile` it.

## A file the build generated {#generated-artifacts}

Some `.lua` files in `src/scripts/` come from nobody: the build makes them and injects them into
the mission every time it runs. They land in the mission folder after extracting a mission that was
already built.

| File | What it is | Where the content is edited |
|---|---|---|
| `veaf-spawn-data.lua` | the spawn database (`_spawn unit` / `_spawn group`) | `src/spawn-groups.yaml` |
| `dcs-bridge.lua` | the runtime bridge used by the tooling | nothing to edit, it is downloaded |

The build leaves them out and tells you so: nothing is broken, your mission gets the fresh version
the build injects. **Delete them from your mission folder** to stop seeing the message.

Do not declare them under `custom_scripts:` — that would freeze an out-of-date copy of data the
build regenerates into your mission.

## Going further {#more}

- [`mission.yaml` reference — `custom_scripts:`](../../MISSION_YAML_REFERENCE.en.md#custom-scripts)
- [Full guide — how scripts are loaded](../GUIDE.en.md)
- [Lua API reference](../../LUA_API_REFERENCE.en.md)
