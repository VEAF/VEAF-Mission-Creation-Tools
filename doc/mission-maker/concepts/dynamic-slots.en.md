# Dynamic slots

## What it is {#what-it-is}

DCS *dynamic spawn*: instead of picking a pre-placed slot, the pilot picks an airfield and an
aircraft type, and DCS puts them on a parking spot. Two files feed it:

- `src/dynamic-slot-templates.yaml` — the **templates**: one group per aircraft type, flagged
  `dynSpawnTemplate: true`, describing the aircraft that will be served (payload, livery,
  frequencies);
- `src/warehouses.yaml` — **which airfields** open dynamic slots, and with what stock.

Both ship filled in a freshly created folder: a hundred-odd templates, and a `warehouses.yaml` that
fits in a handful of useful lines.

## The smallest example that works {#minimal-example}

It is the shipped file, and it is enough:

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

No `airports:` list: **every** airfield of that coalition is covered. No `aircrafts:` list: the stock
is derived automatically from the templates present in the mission for that coalition. That is why
the file is so short.

On each selected airfield the build then writes `dynamicSpawn = true`, hot start, the stock, and the
link to each type's template.

## What you must do in the DCS editor {#in-the-editor}

**One thing only: give the airfield to a coalition.** With no `airports:` list the build only keeps
airfields whose coalition matches the block, so a neutral airfield is skipped — by design. The rest
— `dynamicSpawn`, hot start, stock, template links — is written by the build; do not set it by hand,
it would be overwritten.

## Restricting, if you want to {#restrict}

```yaml
blue:
  defaults:
    fuel: unlimited
    weapons: unlimited
    hot_start: false          # cold start only
  airports:
    Senaki-Kolkhi: {}
    Kutaisi:
      aircrafts:
        A-10C_2: { amount: 50 }
```

Once `airports:` is there, only the listed airfields are configured — and their coalition is no
longer consulted, your list decides. Once an airfield has an `aircrafts:` list, it replaces the
automatic choice for that airfield.

The build then reports the result: "Warehouses: 2 airports configured, 53 template links".

## The gotcha {#gotcha}

**The shipped templates are a starting point, not a ready-made catalogue.** DCS gives the pilot the
aircraft exactly *as the template describes it*. Among the shipped templates, only a small minority
carry a payload: an A-10C II comes out armed and painted, a UH-1H or an F/A-18C comes out **bare**.

To hand out equipped aircraft, configure them once in a mission in the DCS editor, then regenerate
the file from that mission.

```powershell
.\veaf-tools.exe extract-aircraft-groups my-mission.miz --kind dynamic-template
```

!!! note "The stock is filtered by what the field can park"
    **DCS only offers what the airfield can park**, and the build takes that into account: the stock
    is filled only with what the field's parking actually accepts. An airfield with helicopter-only
    spots is no longer given 149 aircraft types that will never appear. The build says nothing about
    it — this is not an error, it is the stock becoming accurate. The filter only applies on
    **Caucasus, Persian Gulf and Syria**, the only maps for which parking data exists; everywhere
    else the behaviour is unchanged.

## Going further {#more}

- [Pipeline reference — step 4, warehouses](../../PIPELINE_REFERENCE.en.md#pipeline-step-4-warehouses)
- [Pipeline reference — step 3, aircraft groups](../../PIPELINE_REFERENCE.en.md#pipeline-step-3-aircraft-groups)
- [CLI reference — `extract-aircraft-groups`](../../CLI_REFERENCE.en.md#extract-aircraft-groups)
- [Spawnable groups](spawnables.en.md) — the other family of aircraft groups
