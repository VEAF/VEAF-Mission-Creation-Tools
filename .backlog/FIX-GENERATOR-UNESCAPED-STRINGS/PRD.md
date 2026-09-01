# FIX-GENERATOR-UNESCAPED-STRINGS — a quote in a config value silently breaks the whole mission

Status: ✅ done

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

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | One helper for every mission-supplied string, and the reason for each site that keeps none | low — the helper already existed and was already used a dozen times in this file; 104 tests red before, green after, four sabotages | ✅ |
| 02 | The build refuses to ship a `veaf-config.lua` that does not parse | medium — a hand-written Lua 5.1 parser is new code on the build path, cross-checked against `luac -p` over 112 real files with zero disagreements | ✅ |
| 03 | Write a coordinate the way DCS shows it | low — documentation only, both languages, `docs-check` clean | ✅ |

## Definition of done

- [x] One escaping helper, used by every site that writes a mission-supplied string into Lua —
      not six repairs. It already existed (`veaf_libs/lua_literals.py`, SECREV-2); the work was
      routing the sites that never adopted it
- [x] The sites enumerated and each one either routed through it or shown not to need it, with the
      reasoning recorded — **59, not 31** (ticket 01), of which 52 routed and 7 justified
- [x] A test per free-text field driving a value containing `"`, `\` and a newline — 52 fields,
      104 red before the change
- [x] **The build refuses to ship a `veaf-config.lua` that does not parse**, and says which line
- [x] That check is itself proven to fail: a `settings:` key containing a quote stops the build and
      leaves no file behind, while the same mission with a valid key still builds
- [x] `zone_center_coordinates` documented with a coordinate containing seconds — it already was, so
      what the pages gained is *why*, and the two ways YAML lets you write it (ticket 03)

## What implementation found that this document did not say

Written down rather than folded in silently, since this PRD was an hour old and written from a defect
found in game:

1. **The helper was not missing.** `veaf_libs/lua_literals.py` was written for this exact problem in
   the 2026-07-01 security review, and `lua_config_generator` already imported it for briefings,
   radio-menu labels and named points. Fifty sites next door never adopted it. "One helper, not six
   repairs" was the right instruction; it was already half-done.

2. **59 interpolations, not 31.** The PRD's count came from a line-based scan of `lines.append(f…)`.
   An AST walk — an expression counts when it sits between an odd and an even `"` of its f-string's
   literal parts — finds 59 across 54 statements. Two of them are not Lua at all: they emit lines of
   the `mission.yaml` scaffold, where quoting them as Lua would corrupt the file.

3. **`luadata` cannot be the guard.** The PRD suggested looking at it. It is a data deserialiser and
   rejects `veaf.setConfig("A", "enable", false)` — the first line of real code in the file. The
   guard is a Lua 5.1 grammar transcribed in `veaf_libs/lua_syntax.py` instead.

4. **One site cannot be fixed by quoting.** The v6-migration hint is written into a Lua `--` comment,
   which ends at the first line break; a value carrying one escapes the comment whatever the quoting.
   `lua_comment_line` folds the breaks out.

5. **The documentation was already right.** Both AirWaves pages, the shipped default `mission.yaml`,
   the template and the three test missions all showed the seconds form with its `\"` escapes. The
   field was documented correctly and the tool broke on it, which is a sharper statement than "the
   documented field is unusable as documented".

6. **A neighbouring family the guard covers but the escaping does not.** A `settings:` key is written
   as a bare Lua name (`veaf.config.{key} = …`), so a quote in one is a syntax error rather than a
   quoting fault. Nothing to escape; the guard stops it. Two more sites of the original family live
   in `veaf_mission_mcp/edit_veaf_config.py` and are named in ticket 01 — MCP editing surface, not
   the build, and deliberately left for their own lot.

## Worth knowing

`veaf.computeLLFromString` accepts spaces as separators just as well as `°'"`, so
`N42 00 00 E042 00 00` is the same position without a quote. That is the workaround in the session
mission today — a workaround, not the fix.
