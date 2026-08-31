# Spawnable groups

## What it is {#what-it-is}

Two families of "things to spawn in game", declared in different places.

| | File | What it is | How you call it |
|---|---|---|---|
| **Aircraft** | `src/spawnables.yaml` | template aircraft groups, prefixed `veafSpawn-` | radio menu commands / markers |
| **Ground and sea** | `src/spawn-groups.yaml` | aliases pointing at unit compositions | `_spawn unit <alias>` / `_spawn group <alias>` |

## The smallest example that works — ground and sea {#minimal-example}

`src/spawn-groups.yaml` ships fully commented: as-is it adds nothing. Uncomment and adapt:

```yaml
units:                              # -> `_spawn unit <alias>`
  - aliases: [myaaa]
    unitType: ZSU-23-4 Shilka

groups:                             # -> `_spawn group <alias>`
  - aliases: [mysam]
    disposition: {h: 3, w: 3}       # layout grid, in 10 m cells
    units:
      - {type: ZSU-23-4 Shilka, cell: 1}
      - {type: Ural-375, random: true}
      - {type: Soldier M4, number: {min: 2, max: 4}, random: true}
    description: My custom SAM site
    groupName: MySAM
```

In game, an F10 map marker reading `_spawn group, name mysam` spawns the composition there. The
marker syntax is in the [aliases](../../ALIASES.en.md).

## The smallest example that works — aircraft {#aircraft-example}

This one is not written by hand: a DCS aircraft group runs to hundreds of lines. You build it in the
DCS editor, name it with the `veafSpawn-` prefix, then extract it:

```powershell
veaf-tools.exe extract-aircraft-groups my-mission.miz --kind spawnable
```

`src/spawnables.yaml` is rewritten with your groups. The next build injects them back.

## The gotcha {#gotcha}

**The name prefix decides the family**, not the file. An aircraft group named `veafSpawn-…` belongs
in `spawnables.yaml`; a group flagged `dynSpawnTemplate: true` belongs in
`dynamic-slot-templates.yaml` — and the `dynSpawnTemplate` flag wins over the prefix if a group
carries both.

Second gotcha: an entry in `spawn-groups.yaml` reusing an alias the framework already knows
**replaces** it. Useful to redefine a standard group, surprising when it was not intended.

## Going further {#more}

- [Pipeline reference — step 3, aircraft groups](../../PIPELINE_REFERENCE.en.md#pipeline-step-3-aircraft-groups)
- [Pipeline reference — step 5, spawn data](../../PIPELINE_REFERENCE.en.md#pipeline-step-5-spawn-data)
- [veafSpawn](../scripts/veafSpawn.en.md) — the in-game commands
- [Marker aliases](../../ALIASES.en.md)
- [Dynamic slots](dynamic-slots.en.md) — the third family of aircraft groups
