# FIX-CSAR-YAML-SETTINGS — the CSAR settings a mission maker can actually reach

Status: ✅ done

Origin: Tripack, 2026-09-22, in the `/ask` thread of 2026-09-12
([1548450049820729385](https://discord.com/channels/471061487662792715/1548450049820729385)), after
being told his Lua block was unnecessary:

> Ahhh mais je n'ai pas trouvé dans la doc le moyen de paramétrer `csarOncrash`, `enableForAI`,
> `enableForRED` dans le mission.yaml […] C'est pour ça que je voulais passer par le
> mission-script.lua

## What is missing

Measured on `develop` at 6.24.0: those three keys appear **nowhere** in `doc/` — zero occurrences,
all files, both languages.

The YAML-first section of the guide
([GUIDE.md:850](../../doc/mission-maker/GUIDE.md)) shows three example settings — `enableAllslots`,
`useprefix`, `csarPrefix` — and the line *"paires csar.xxx = valeur"*. Formally complete, and
useless to someone looking for a specific setting: `CSAR.lua` defines **34 scalar settings** that
`mission.yaml` can reach, and the guide names 3 of them, as examples rather than as a list.

That is the whole story of the thread. Tripack did not choose Lua over YAML; he wrote Lua because
nothing told him YAML could do it.

This sits one layer below [FIX-SUPPORT-ASK-ANSWERS-THE-NEED](../FIX-SUPPORT-ASK-ANSWERS-THE-NEED/PRD.md):
the bot could not have given the YAML answer from the documentation, because the documentation does
not contain it. Fixing retrieval would not have helped.

## Two defects found while measuring it

**A list in `settings:` reaches Lua as a Python repr.** `_to_lua_scalar` falls through to
`lua_scalar`, which stringifies anything it does not recognise. Measured:

| YAML value | generated Lua |
|---|---|
| `true` | `true` |
| `20` | `20` |
| `"MEDEVAC"` | `"MEDEVAC"` |
| `["helicargo", "MEDEVAC"]` | `"['helicargo', 'MEDEVAC']"` |
| `{a: 1}` | `"{'a': 1}"` |

The last two are syntactically valid Lua and semantically nonsense, written without a warning.

**The documented example crashes CSAR.** The guide's own block sets `useprefix: true` and
`csarPrefix: "MEDEVAC"`. `CSAR.lua:32` defaults `csarPrefix` to a table, and `CSAR.lua:1916` walks
it with `pairs` under exactly that `useprefix == true` branch. Proved on Lua 5.1.5:

```
pairs("MEDEVAC") -> bad argument #1 to 'pairs' (table expected, got string)
```

So a mission maker who copies the documented example gets a runtime error, from the page that is
supposed to teach the simple path.

## CTLD is not affected — measured, not assumed

The question was asked for CTLD too. It does not have this defect: its settings live in the mission
maker's own `ctld-config.yaml`, validated by `ctld-tools`, whose defaults ship as a readable
1042-line YAML block embedded in `CTLD.lua` (`ctld.configDefault`). Only 4 `ctld.xxx` assignments
exist at the root, and none of them is a user setting. The reader has the list in a file they own;
the CSAR reader has no file at all. Nothing to do here.

## Tickets

| # | Title | Status |
|---|---|---|
| 01 | [A list in settings reaches Lua as a table](tickets/01-lists-reach-lua-as-tables.md) | ✅ |
| 02 | [The documented example must not crash](tickets/02-the-documented-example-crashes.md) | ✅ |
| 03 | [List the CSAR settings, FR and EN](tickets/03-list-the-settings.md) | ✅ |

Sequencing: 01 before 03 — whether `csarPrefix` can be documented as a YAML list depends on it.

## What shipped, and the two things measuring it corrected

A YAML list now generates a Lua table constructor, recursively, so a nested list needs no second
code path; a mapping is **refused** naming the setting, because nothing consumes a keyed table from
`settings:` and silence is what caused this lot. The refusal immediately found a second defect:
`RADIO.user_menus` was the one structured module key missing from `_SKIP_SETCONFIG_KEYS`, so every
mission with YAML radio menus carried a whole Python repr of its menu tree in `veaf-config.lua`,
written by a `setConfig` call nothing reads. Enumerated rather than sampled — `_emit_module_body`
reads nine such keys, eight were listed — and the enumeration is now the test.

**The count above was wrong, and it mattered for what the documentation says.** This PRD and ticket
03 both said `csarFixedUnits`, `bluemash` and `redmash` were tables of tables needing the Lua
callback. Read in the script rather than recalled: they are flat lists of strings (lines 36, 129,
142), exactly like `csarPrefix`. Only `aircraftType` is keyed. So `mission.yaml` reaches **38** of
CSAR's settings, not 34, and the page says there is exactly **one** it cannot reach — which is a
sharper sentence than "complex settings", the vagueness that started the thread.

The guard ended up wider than ticket 02 asked for: instead of running the one documented block, it
compares every documented example against every `CSAR.lua` default **by Lua type**, and sweeps the
other direction so a setting gained upstream cannot stay undocumented.
