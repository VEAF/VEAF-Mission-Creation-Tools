# Dynamic slots

## What it is {#what-it-is}

DCS *dynamic spawn*: instead of picking a pre-placed slot, the pilot picks an airfield and an
aircraft type, and DCS puts them on a parking spot. Two files feed it:

- `src/dynamic-slot-templates.yaml` — the **templates**: one group per aircraft type, flagged
  `dynSpawnTemplate: true`, describing the aircraft that will be served (payload, livery,
  frequencies);
- `src/warehouses.yaml` — **which airfields** open dynamic slots, and with what stock.

`warehouses.yaml` fits in a handful of useful lines, and it ships in a freshly created folder. The
template catalogue does not need to be in your folder at all: see just below.

## Where the template catalogue comes from {#shipped-catalogue}

A template catalogue ships with veaf-tools, and it grows with every release. Your mission folder
gets **no copy** of it: it gets an empty `src/dynamic-slot-templates.yaml`, and the build reads the
shipped catalogue. So you get the templates added since, automatically, just by updating the tool.

Three situations, one rule:

| Your `src/dynamic-slot-templates.yaml` | What the build injects |
|---|---|
| absent, or empty | the shipped catalogue, in full — and the build says so in its report |
| holding at least one group | **yours, alone**: the shipped catalogue is no longer read |
| either of those, with `dynamic_slot_templates: false` in `mission.yaml` | nothing |

In other words, an empty file means "I add nothing to the shipped catalogue", and **not** "I want no
dynamic slots". To inject nothing at all, it is `dynamic_slot_templates: false` under the
`pipeline:` key of `mission.yaml`, and nothing else.

As soon as you write a single group into your file, it stands alone. Nothing is merged behind your
back: your settings stay exactly what you wrote, even when a new release of the tool ships a
template of the same name.

### Taking in the new templates, à la carte {#pull-new-templates}

That is the trade-off: your file will never move on its own again, so picking up what is new takes
a gesture. It is selective — you take what you want, not everything.

First see what is missing, which writes nothing:

```powershell
.\veaf-tools.exe content pull-aircraft-groups
```

Then take one template by name, or every missing one:

```powershell
.\veaf-tools.exe content pull-aircraft-groups --add "F-14BU Template"
.\veaf-tools.exe content pull-aircraft-groups --add-new
```

**A template you already have is never replaced**, even when the shipped catalogue holds a different
version of it — which is exactly why this command exists instead of an automatic merge. The report
lists them as kept, so you know what was left aside and why. And a template you deleted on purpose
stays deleted until you ask for it back.

The same mechanism covers [spawnable groups](spawnables.en.md): same shipped catalogue, same
command, with `--kind spawnable`.

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

**Ships and FARPs are handled the same way**, with nothing more to write: an aircraft carrier, a
helicopter-capable ship or a FARP belonging to the coalition opens its dynamic slots just like an
airfield. Each gets what it can actually host — a carrier takes planes and helicopters, a FARP or a
frigate takes helicopters only — and a ship with no flight deck, a tanker for instance, is left
untouched.

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

Ships and FARPs restrict the same way, with `ships:` and `farps:`. Name them by the **unit name** as
it appears in the editor, or by its id:

```yaml
blue:
  defaults:
    fuel: unlimited
  ships:
    CSG-74 Stennis: {}
  farps:
    FARP Kaspi MM54:
      aircrafts:
        UH-1H: { amount: 20 }
```

**The three lists are independent**: naming a ship says nothing about the FARPs, which keep the "all
of this coalition" behaviour. To restrict one without opening the other, write the empty list:
`farps: {}`.

The build then reports the result: "Warehouses: 2 airports configured, 3 ships/FARPs, 53 template
links".

## The gotcha {#gotcha}

**The shipped templates are a starting point, not a ready-made catalogue.** DCS gives the pilot the
aircraft exactly *as the template describes it*. Among the shipped templates, only a quarter carry a
payload: an A-10C II or an F/A-18C comes out armed and painted, a UH-1H or an AV-8B comes out
**bare**.

To hand out equipped aircraft, configure them once in a mission in the DCS editor, then regenerate
the file from that mission.

```powershell
.\veaf-tools.exe extract-aircraft-groups my-mission.miz --kind dynamic-template
```

From then on your file is no longer empty: it stands alone, and the shipped catalogue is no longer
read for this mission. That is the intent — your payloads are your payloads — and
[`pull-aircraft-groups`](#pull-new-templates) is there to fetch what you are missing.

!!! warning "Two warnings worth reading"
    The build now reports two situations that break nothing and still leave the slots unusable. **A
    template link that leads nowhere**: DCS renders it as *Group template: None* in the Resource
    Manager, which reads like a deliberate choice. Those are leftovers from an earlier build, on a
    warehouse your configuration does not target — declare the coalition concerned, or clear them in
    the editor. **Templates with nowhere to be offered from**: if the mission carries templates and
    no airfield, ship or FARP belongs to a coalition, no dynamic slot will appear. That is the state
    of a brand-new mission, whose airfields are all neutral.

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
- [CLI reference — `pull-aircraft-groups`](../../CLI_REFERENCE.en.md#pull-aircraft-groups)
- [Spawnable groups](spawnables.en.md) — the other family of aircraft groups
