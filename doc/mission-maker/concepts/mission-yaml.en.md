# `mission.yaml` and its modules

## What it is {#what-it-is}

The configuration file at the root of the mission folder. Two things matter above all: the
`mission:` block (identity) and the `modules:` block (**which VEAF features are active**). The build
derives `src/scripts/veaf-config.lua` from it, and that is what the scripts read in game.

## The smallest example that works {#minimal-example}

```yaml
mission:
  name: My-Mission

modules:
  # Infrastructure: mandatory, nothing after the colon
  UNITS:
  TIME:
  CACHE:
  EVENTS:
  MARKERS:
  COMMANDS:
  # Features: true to enable
  RADIO: true         # the VEAF F10 radio menu
  SPAWN: true         # spawn units from the F10 map
  SHORTCUTS: true     # the built-in aliases (-shilka, -sa2, …)
  INTERPRETER: true
  # Community scripts: written out even when off — see "The gotcha" below
  STTS: false
  CTLD: false         # configured in ctld-config.yaml, beside this file
  CSAR: false
  AIEN: false
  SKYNET: false
```

That is exactly what `prepare --template minimal` produces. A VEAF module absent from the block is
not shipped at all — the community scripts follow the opposite rule, which is why the generated file
writes every one of them out, even at `false`.

## The three forms of a module {#three-forms}

| Form | Meaning |
|---|---|
| `UNITS:` | infrastructure module, always active, no configuration |
| `RADIO: true` | enabled with its default configuration (`false` to disable) |
| `RADIO:` then an indented block | enabled **and** configured; `enabled: true` is implied |

The long form is what you use as soon as a module has settings:

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Alpha Zone
```

Some modules **require** their block (`ASSETS`, `SANCTUARY`, `COMBATZONE`, `QRA`, `AIRWAVES`): the
shipped `mission.yaml` shows them commented out, ready to uncomment.

## The gotcha {#gotcha}

**Dependencies are added for you.** `COMBATZONE` needs `SPAWN`; `CASMISSION` needs `SPAWN` **and**
`GROUNDAI`. Enable the feature without its dependency and the build enables it for you, saying so in
a warning — even if you had explicitly set it to `false`. So the `modules:` you write is not exactly
the one that runs: read the build's warnings.

And a YAML gotcha: `MODULE:` (nothing after the colon) and `MODULE: false` do not mean the same
thing. The first is "infrastructure, active"; the second is "off".

**The five *opt-out* community scripts work the other way round from VEAF modules.** `STTS`, `CTLD`,
`AIEN`, `CSAR` and `SKYNET` are **active when you do not mention them**: their absence from the
`modules:` block means "keep your default state", and their default is on. An absent VEAF module, by
contrast, is not shipped. That is why every scaffold (`prepare --template`, `convert-v5`, the shipped
`mission.yaml`) writes them out **explicitly**, `true` or `false`: a `false` can be read, an omission
that means "enabled" cannot. Do the same when you write the file by hand — otherwise the build ships
CTLD in a mission that never names it.

## Going further {#more}

- [`mission.yaml` reference — `modules:`](../../MISSION_YAML_REFERENCE.en.md#modules)
- [Full guide — configuring modules](../GUIDE.en.md#configuring-modules)
- [Full guide — security tiers](../GUIDE.en.md#security-tiers)
- [Script catalogue](../scripts/README.en.md) — what each module does
