# The Lua files in your folder

The build takes stock of `src/scripts/` on every run, and tells you what it finds there that it did
not expect. None of these messages stops the build, and none of them means a file was lost — but
their tone can suggest otherwise, which is exactly what prompted this page.

## The three kinds of `.lua` {#three-kinds}

The build sorts every file in `src/scripts/` into one of three boxes, and the message you get
depends only on the box:

| Kind | Files | What the build does with them |
|---|---|---|
| **Expected** | `mission-script.lua`, `veaf-config.lua`, `veafDynamicConfig.lua`, `ctld-config.yaml`, the override script | Handles them, silently |
| **Declared** by you | everything listed under `custom_scripts:` in `mission.yaml` | Embeds them, and says so in verbose mode |
| **Generated** by itself | `veaf-spawn-data.lua`, `dcs-bridge.lua` | **Ignores** the folder's copy and injects its own |

Everything else is "unexpected". That is not an accusation: it is simply a file the build does not
know what you want done with.

## An unexpected Lua file {#builder-unexpected-lua-file}

> Unexpected Lua file 'src/scripts/myScript.lua' found in your mission folder. This file will be
> included in the build. You can declare it under 'custom_scripts' in mission.yaml to suppress this
> warning.

**Read the second sentence: the file *is* embedded.** Nothing is left out, nothing is lost. The
build is only telling you that it loads the file without knowing when you wanted it loaded.

**How to reproduce it.** Drop any `.lua` into `src/scripts/` without declaring it, and rebuild.

**The ways out.**

| Way out | When |
|---|---|
| Declare it under `custom_scripts:` | It is your script and you want it — you also gain control over load order and delay |
| Delete it from the folder | It is a leftover you no longer use |
| Do nothing | The message comes back on every build, the script works |

**What it is not.** Not a rejected file, not a syntax error, not a conflict. See
[Custom scripts](../concepts/custom-scripts.en.md) for how to declare it.

## A file the build generates itself {#builder-generated-artifact-in-sources}

> 'src/scripts/veaf-spawn-data.lua' is not a script anybody wrote: the build generates it and
> injects it into the mission every time. It usually lands there after extracting a mission that
> was already built. It is left out of this build, so nothing is broken — delete it from your
> mission folder to silence this. Do NOT declare it under 'custom_scripts:': that would freeze an
> out-of-date copy into your mission.

**Where it comes from.** You extracted a mission folder from an already-built `.miz`. The
extraction handed the folder back what the build had injected — its own output, returned as input.

**What to do.** Delete it from the folder. Your mission gets the fresh version the build injects
anyway; the one in the folder is of no use.

**What you must not do.** Declare it under `custom_scripts:`. That is the one action that really
breaks something: it freezes into your mission an out-of-date copy of data the build regenerates
every time. Reported by Tripack in September 2026, where two copies of the same tables ended up
embedded together.

**What it is not.** Not a loss: the file is ignored **for this build**, not deleted from your disk,
and the mission does contain the data. Details of the files concerned in
[Custom scripts](../concepts/custom-scripts.en.md#generated-artifacts).

## …and it is the spawn database {#builder-generated-artifact-spawn-data-hint}

> 'veaf-spawn-data.lua' holds the spawn database used by '_spawn unit' and '_spawn group'. To add
> or override your own spawnables, edit 'src/spawn-groups.yaml' — never the Lua.

The previous message followed by this one, because this is the one of the two generated files you
might legitimately want to change. The answer is: yes, but somewhere else — in
`src/spawn-groups.yaml`, which the build reads to produce that Lua. See
[Spawnable groups](../concepts/spawnables.en.md).

## This script loads other scripts {#builder-custom-loader-hint}

> 'src/scripts/myLoader.lua' appears to load other Lua scripts (loadfile/dofile/require). In v6 you
> no longer need a custom loader: list your scripts under 'custom_scripts:' in mission.yaml (each
> loaded at the right time, before/after mission-script.lua, with a load trigger generated
> automatically). See the documentation. A leftover v5 loader can then be deleted.

**What it means.** Your file contains a `loadfile`, a `dofile` or a `require`. In v5, that was how
you loaded several scripts; in v6, `custom_scripts:` does it for you, and throws in control over
order and delays.

**It always comes after the previous message**, never on its own: it is a detail about a file
already flagged as unexpected.

**The ways out.** Migrate to `custom_scripts:` and delete the loader, or leave it as it is — it
still works.

## A declared file is taken into account {#builder-custom-lua-included}

> Custom Lua file 'src/scripts/myScript.lua' declared in mission.yaml and will be included in the
> build.

**Nothing to do.** This is a confirmation, not a warning — the exact counterpart of the "unexpected
file" message.

It is an *info*-level message: in an interactive terminal it appears on the status line, which
immediately rewrites itself, so you will probably only catch it out of the corner of your eye. To
read it back, add `--verbose`, or redirect the output to a file — in both cases the lines scroll
and stay.

## A declared script does not exist {#validate-custom-script-missing}

> custom_scripts: declared script 'src/scripts/myScript.lua' does not exist.

**The opposite of the previous ones**: `mission.yaml` announces a file the folder does not hold. A
typo in the path, a file never copied, or a script deleted without cleaning up the declaration.

**The ways out.** Fix the path, add the file, or remove the entry from `custom_scripts:`.

## MiST was injected for your scripts {#builder-mist-injected-for-custom-scripts}

> MiST is no longer injected by default, but 'src/scripts/myScript.lua' calls it: injecting it for
> this mission. Set MIST: true under modules: to ask for it explicitly.

**Nothing is wrong, and the build did you a favour.** MiST used to be embedded in every mission;
that is no longer the case. The build saw that your script calls it and injected it anyway, rather
than leaving you to discover a nil `mist` in the air.

**The recommended way out.** Write `MIST: true` under `modules:` in `mission.yaml`: the dependency
becomes explicit, and no longer relies on the build's ability to guess it from your code.

**What it is not.** Not an error, and not a reason to drop MiST from your script if you need it.

## Going further {#more}

- [Build messages](README.en.md) — the other families
- [Custom scripts](../concepts/custom-scripts.en.md) — declaring, ordering, delaying
- [`mission.yaml` reference — `custom_scripts:`](../../MISSION_YAML_REFERENCE.en.md#custom-scripts)
