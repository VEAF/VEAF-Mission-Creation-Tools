# FIX-GENERATOR-UNESCAPED-STRINGS — a quote in a config value silently breaks the whole mission

Status: ✅ done · archived 2026-09-28

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

---

## Tickets, in full

## 01 — One helper for every mission-supplied string, and the reason for each site that keeps none

Status: ✅ done
Type: fix

### What was wrong

`lua_config_generator` wrote mission values into generated Lua by interpolating them into a
double-quoted literal: `f'{indent}    :setZoneCenterFromCoordinates("{coords}")'`. Whatever the value
contained went in raw. A DCS coordinate written with seconds contains a `"`, so it closed the literal
and the file stopped being Lua after that character.

**The helper already existed.** `veaf_libs/lua_literals.py` was written for exactly this in the
2026-07-01 security review (VMR-010 / VMR-012), and the generator already imports it — under the
private aliases `_emit_lua_string` and `_lua_long_string` — for briefings, radio-menu labels and
named points. The defect is not a missing helper; it is fifty-odd sites that never adopted it, next
to a dozen that did. So the work here was routing, not designing.

### The enumeration

Counted with an **AST walk**, not a regular expression over `lines.append(f…)`: an expression counts
when it is a `FormattedValue` sitting between an odd and an even `"` of the surrounding f-string's
literal parts. That catches concatenations, assignments and multi-line f-strings the line-based count
misses.

**59 expressions, in 54 statements** — the PRD said 31, which is what the line-based count sees.

After the change, **7 remain**, every one of them with a reason:

| Remaining site | Expression | Why it needs no escaping |
|---|---|---|
| `mission_identity_section` | `live_name` | Emits a line of **`mission.yaml`**, not Lua. Quoting it as a Lua literal would corrupt the scaffold. |
| `generate_mission_yaml_template` | `mid` | Same: a `mission.yaml` key, and a module id besides. |
| module `setConfig` block ×4 | `mod_id` | Not a YAML key: the loop runs over `_MODULE_INIT_ORDER` plus the ids `get_modules()` knows, so a value the mission maker invents is dropped before this line. A closed set the generator owns. |
| community-script block | `sid` | Same, from `get_community_script_files()`. |

The other 52 are routed. Two destinations, because the position decides:

* `_lua_text` → `lua_string`, for every value in an argument or a right-hand side. It prefers a long
  string when the value needs escaping, which keeps generated configuration readable — a briefing
  emerges as `[[…]]` rather than a wall of `\n`.
* `_lua_key` → `lua_quoted_string`, for the three `veafSecurity.password_*[…]` table keys **only**.
  A long string in an index position produces `t[[[value]]]`, which Lua's lexer reads as `t` called
  with the long string `[value` followed by a stray `]`. An index always gets the escaped `"…"` form.

### The site quoting cannot fix

`_emit_combat_zone_def` writes a v6-migration hint into a Lua **comment**. A `--` comment ends at the
first line break, so a zone name carrying one pushes the rest of itself out of the comment and into
the file as code — and there is nothing to quote inside a comment. `lua_literals.lua_comment_line`
folds the line breaks out; it sits beside the quoting helpers because it answers the other half of
the same question.

### Out of scope, found by the same sweep

The enumeration was run over the whole Python tree, not just the generator. Two sites outside it write
Lua the same way and are **not** touched here — they belong to the MCP editing surface rather than the
build:

* `veaf_mission_mcp/edit_veaf_config.py:56-57` — `module_id` is interpolated into both a regex and a
  generated `veaf.setConfig(…)` line.
* `veaf_mission_mcp/edit_veaf_config.py:126` — `_lua_value` escapes the backslash and the quote but
  **not the newline**, so a multi-line value still produces a broken literal.

One more, inside the generator but outside this family: a `settings:` key is written as a bare Lua
name (`veaf.config.{key} = …`), so a quote in one is a syntax error rather than a quoting problem.
Ticket 02's guard catches it, and it is what ticket 02's test uses to prove the guard fires.

### Tests

`test/python/veaf_libs/test_lua_config_escaping.py` drives one value — `quote " backslash \ newline`
plus a second line, the three characters that break a Lua string literal in one string — through
**52 free-text fields**, and asks two questions of each: does the file parse, and did the value arrive
whole. 104 of the 105 tests in the file were red before the change.

Both were proven able to fail:

| Sabotage | Effect |
|---|---|
| `{_lua_text(coords)}` back to `"{coords}"` | 4 red, including the end-to-end build test |
| `lua_string` strips `"`, `\` and newlines instead of quoting them | 5 red — the file still parses, the preservation test catches it |
| `lua_comment_line` returns its input | 2 red, the comment case only |
| `_lua_key` routed through `lua_string` | 4 red, the three table keys |

---

## 02 — The build refuses to ship a `veaf-config.lua` that does not parse

Status: ✅ done
Type: fix

### Why this half matters more

The build **succeeded**. It wrote a `.miz`, said nothing, and the defect surfaced only in `dcs.log`
after the mission was loaded — where DCS refuses the file *as a whole*, so no VEAF module initialises
at all. Ticket 01 fixes the values known today; this ticket is what catches the next one.

### Which check, and why not the obvious two

**`luac -p`** answers the question in milliseconds and is what was used to cross-check this work. It
is not a candidate for the guard: it is absent from the CI runners, from the shipped one-file
executable, and from a mission maker's machine. A guard that only runs where an optional tool is
installed is a guard-shaped hole — the build would go on reporting success everywhere it matters.

**`luadata`**, which the repository bundles and which the PRD suggested looking at, cannot serve.
Measured: it is a *data* (de)serialiser for a Lua table literal, and it rejects the first line of real
code in the file.

```
>>> luadata.unserialize('veaf.setConfig("A", "enable", false)')
ValueError: Unserialize luadata failed on pos 15: unexpected character.
```

So `veaf_libs/lua_syntax.py` transcribes the Lua 5.1 grammar — the version DCS runs — as a
tokeniser and a recursive-descent parser in pure Python. It builds no tree and evaluates nothing; it
answers "would Lua refuse this file, and on which line". `generate_config_lua` reads back what it
wrote before returning it, so **every** caller is covered rather than the one that was patched, and
`write_config_lua` turns the failure into a localised build error naming the line and quoting it.

### Proving it both ways

A parser can be wrong in two directions and each has its own test.

*Too strict* would break every build over Lua it never learned. `test_every_veaf_runtime_script_parses`
runs it over every file under `src/scripts/veaf` — 48 files of hand-written 5.1 that DCS actually
runs, none of them written with this parser in mind. Cross-checked against `luac -p` over all of
`src/scripts` (63 files, community scripts included) and `test/lua` (49 files): **112 files, zero
disagreements in either direction**.

*Too permissive* is the state the build was in. Thirteen broken chunks, each a shape an unescaped
value produces, are rejected on a named line — and the parser was measurably too permissive once: it
accepted `f() = 1` until the test caught it.

The guard itself is proven able to fail on a **real mission**, not a hand-built string. A `settings:`
key becomes a bare Lua name, so `'BAD" KEY': 1` produces a file that does not parse:

* with the broken key, `write_config_lua` raises and **writes no file**;
* with a valid key, the same mission builds;
* the coordinate that broke the session mission now builds, end to end.

Sabotaging `check_lua_syntax` into `pass` turns 16 tests red.

### What the mission maker sees

```
Cannot build: the generated veaf-config.lua is not valid Lua at line 89 (')' expected near 'E042').
DCS refuses the whole file, so no VEAF module would start — no radio menu, no spawn.
The line reads: :setZoneCenterFromCoordinates("N42°00'00" E042°00'00"")
```

---

## 03 — Write a coordinate the way DCS shows it

Status: ✅ done
Type: doc

### What the pages already said

The PRD expected the documentation to be missing the seconds form. It is not: both
`doc/mission-maker/scripts/veafAirWaves.md` and its `.en.md` twin already showed
`zone_center_coordinates: "N41°00'00\" E044°00'00\""`, twice each — in the YAML example and in the
field table — and so do `src/defaults/mission-folder/mission.yaml`, `mission_template.py` and the
three test missions. The documented form was the right one all along; the tool was what broke on it.

So this ticket adds the part that was missing: **why the value looks like that, and the two ways YAML
lets you write it**. A reader who copies the coordinate out of DCS gets a string with two `"` in it,
and a double-quoted YAML scalar needs each one escaped. The single-quoted form needs no backslash but
doubles the minutes symbol instead. Both were checked to parse to the same string.

Also recorded there: spaces work as separators. `veaf.computeLLFromString` reduces `°`, `'`, `"`,
spaces, `:` and `-` to one separator (`veaf.lua:1060-1066`), so `N41 00 00 E044 00 00` is the same
position with no punctuation at all — worth knowing, and no longer the workaround it was on
2026-09-01.

Both pages carry the same explicit anchor, `{#coordinate-with-seconds}`, per the repository's
convention. `poetry run docs-check` is clean.

---
