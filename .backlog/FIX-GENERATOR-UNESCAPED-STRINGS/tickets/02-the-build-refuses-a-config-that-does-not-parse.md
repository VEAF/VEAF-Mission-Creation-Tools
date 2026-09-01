# 02 — The build refuses to ship a `veaf-config.lua` that does not parse

Status: ✅ done
Type: fix

## Why this half matters more

The build **succeeded**. It wrote a `.miz`, said nothing, and the defect surfaced only in `dcs.log`
after the mission was loaded — where DCS refuses the file *as a whole*, so no VEAF module initialises
at all. Ticket 01 fixes the values known today; this ticket is what catches the next one.

## Which check, and why not the obvious two

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

## Proving it both ways

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

## What the mission maker sees

```
Cannot build: the generated veaf-config.lua is not valid Lua at line 89 (')' expected near 'E042').
DCS refuses the whole file, so no VEAF module would start — no radio menu, no spawn.
The line reads: :setZoneCenterFromCoordinates("N42°00'00" E042°00'00"")
```
