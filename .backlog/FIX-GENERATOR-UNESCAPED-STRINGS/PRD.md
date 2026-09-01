# FIX-GENERATOR-UNESCAPED-STRINGS — a quote in a config value silently breaks the whole mission

Status: ⬜ ready

Found in game on 2026-09-01, preparing the release-gate session: **the mission had no VEAF radio menu
at all**. Not a missing module — *nothing* had initialised.

## What happened

The wave zone was declared with a coordinate written the way DCS itself displays one:

```yaml
zone_center_coordinates: "N42°00'00\" E042°00'00\""
```

`lua_config_generator` interpolates that value straight into a double-quoted Lua string:

```lua
:setZoneCenterFromCoordinates("N42°00'00" E042°00'00"")
```

The `"` of the seconds closes the string. DCS refused the file:

```
ERROR SCRIPTING (Main): Mission script error: [string "l10n/DEFAULT/veaf-config.lua"]:89:
                        ')' expected near 'E042'
```

One bad character, and **no module initialises** — no radio menu, no spawn, no assets. The mission
loads and looks normal until you press F10.

## Why nobody hit it before

`zone_center_coordinates` is the alternative to `trigger_zone_name`, and everyone uses the trigger
zone. But **every DCS coordinate written with seconds contains a `"`** — it is the symbol for
seconds, and the form the game shows. So the documented field is unusable as documented.

## It is not one line

Enumerated across `lua_config_generator.py` (not sampled): **31 distinct expressions** are
interpolated into a double-quoted Lua string with no escaping. Six of them are free text a mission
maker writes:

| Value | Where |
|---|---|
| `coords` | `zone_center_coordinates` — the one that fired |
| `zone_name`, `friendly_name`, `elem_name` | combat zones |
| `name` | most builders |
| `desc` | descriptions, shown in messages |

A combat zone named `Zone "Alpha"` breaks a mission exactly as thoroughly.

## The guard that is missing, and matters more than the fix

**The build succeeded.** It produced a `.miz`, reported no error, and the defect only appeared in
`dcs.log` after loading the mission in the game. Nothing between writing the YAML and flying tells
you the config will not parse.

A generated Lua file that does not parse is the one thing the build can check for itself, cheaply and
completely — `luac -p` on the artefact answers it in milliseconds, and a pure-Python check can too.
Measured while repairing this: a per-line "odd number of double quotes" test finds this defect, and
`luac -p` confirms the repaired file at exit 0.

## Definition of done

- [ ] One escaping helper, used by every site that writes a mission-supplied string into Lua —
      not six repairs
- [ ] The **31 sites enumerated** and each one either routed through it or shown not to need it
      (a value the generator itself produced, a number, an enum), with the reasoning recorded
- [ ] A test per free-text field driving a value containing `"`, `\` and a newline — the three that
      break a Lua string literal
- [ ] **The build refuses to ship a `veaf-config.lua` that does not parse**, and says which line —
      the check that would have caught this before the mission was ever loaded
- [ ] That check is itself proven to fail: a deliberately broken value makes the build stop
- [ ] `zone_center_coordinates` documented with a coordinate containing seconds, since that is the
      form the reader will copy from DCS

## Worth knowing

`veaf.computeLLFromString` accepts spaces as separators just as well as `°'"`, so
`N42 00 00 E042 00 00` is the same position without a quote. That is the workaround in the session
mission today — a workaround, not the fix.
