# FIX-CSAR-YAML-SETTINGS — the CSAR settings a mission maker can actually reach

Status: ✅ done · archived 2026-09-28

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

This sits one layer below [FIX-SUPPORT-ASK-ANSWERS-THE-NEED](FIX-SUPPORT-ASK-ANSWERS-THE-NEED.md):
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
| 01 | [A list in settings reaches Lua as a table](FIX-CSAR-YAML-SETTINGS.md) | ✅ |
| 02 | [The documented example must not crash](FIX-CSAR-YAML-SETTINGS.md) | ✅ |
| 03 | [List the CSAR settings, FR and EN](FIX-CSAR-YAML-SETTINGS.md) | ✅ |

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

---

## Tickets, in full

## 01 — A list in settings reaches Lua as a table

Status: ✅ done

### What is wrong

`_to_lua_scalar` (`veaf_libs/lua_config_generator.py`) delegates to `lua_scalar`, which renders any
unrecognised type through `str`. A YAML list written under `modules.CSAR.settings` therefore reaches
the generated `veaf-config.lua` as a quoted Python repr:

```yaml
modules:
  CSAR:
    settings:
      csarPrefix: ["helicargo", "MEDEVAC"]
```

```lua
csar.csarPrefix = "['helicargo', 'MEDEVAC']"
```

Valid Lua, wrong meaning, no message. The same happens for a mapping.

This is not CSAR-specific: `_to_lua_scalar` has sixteen call sites, so the defect is wherever a
mission maker can write a value that is not a scalar.

### What done means

- A YAML list generates a Lua table literal: `{ "helicargo", "MEDEVAC" }`, each element quoted
  through the existing string helper so a value carrying a quote or a newline stays safe.
- A nested list is **handled**, not refused: the renderer is recursive, so nesting costs no extra
  code path, and refusing it would.  Decided here rather than left open.
- A mapping is **refused** with a message naming the module and the key, rather than written as a
  string. There is no evidence any consumer wants one, and silence is what caused this ticket.
- Tests assert the generated Lua text for each type: bool, int, float, string, list of strings,
  list of numbers, mapping (refusal), and a string containing a quote.

### Why this before the documentation ticket

Ticket 03 has to state whether `csarPrefix` can be set from `mission.yaml`. Today the honest answer
is "no, and trying produces nonsense". After this ticket it becomes "yes, as a list". Documenting
first would mean writing the wrong answer down.

---

## 02 — The documented example must not crash

Status: ✅ done

### What is wrong

The YAML-first CSAR example in `doc/mission-maker/GUIDE.md` (and its `.en.md` twin) reads:

```yaml
modules:
  CSAR:
    enabled: true
    settings:
      enableAllslots: true
      useprefix: true
      csarPrefix: "MEDEVAC"
```

`CSAR.lua:32` defaults `csarPrefix` to a **table**, and `CSAR.lua:1916` iterates it with `pairs`
inside the `csar.useprefix == true` branch — the branch this very example turns on. A string there
raises, measured on Lua 5.1.5:

```
bad argument #1 to 'pairs' (table expected, got string)
```

Copying the documented block is enough to break CSAR at runtime.

### What done means

- The example uses a value CSAR can consume. After ticket 01 that is a YAML list
  (`csarPrefix: ["helicargo", "MEDEVAC"]`); if 01 lands differently, the example drops `csarPrefix`
  rather than showing a form that raises.
- A test covers it. A doc example that raises is a defect the doc build cannot see, so the guard
  belongs in the test suite: feed the documented block through the generator and run the generated
  assignments against the CSAR mocks, asserting the prefix branch survives.
- Both language versions change together, and the support bot's page index is refreshed if titles
  move (`services/support-bot/scripts/refresh_doc_pages.py`).

### Note

Check the same pattern for the other two documented examples, `enableAllslots` and `useprefix`:
both are plain booleans in `CSAR.lua`, so they are fine — but check rather than assume, because
this ticket exists precisely because an example was never run.

### What was done, and what it changed about the guard

The example uses a list, as ticket 01 delivered.  The guard is **wider than this ticket asked for**,
and deliberately: rather than running the one documented block, `test_documented_csar_settings.py`
enumerates every `csar.<name> =` default in `CSAR.lua`, enumerates every `modules.CSAR.settings`
mapping in both guides' YAML blocks, and compares the **Lua type** the generator produces against
the type the script defaults to.  That covers all 38 settings instead of the three in the example,
and it is the property that actually failed — a string where the script walks a table.

Proved able to fail rather than assumed: putting `csarPrefix: "MEDEVAC"` back produces
*"generates `"MEDEVAC"` (string), but CSAR.lua defaults it to a table"*.

`enableAllslots` and `useprefix` were checked, not assumed: both are booleans, both fine.

A fourth test runs the other direction — every setting `CSAR.lua` offers must appear in each guide.
That is the ratchet under ticket 03's table; a setting gained upstream and left undocumented is how
the guide got down to naming 3 of 34.

---

## 03 — List the CSAR settings, FR and EN

Status: ✅ done

### What is missing

`CSAR.lua` defines 34 scalar settings reachable from `modules.CSAR.settings`. The guide names 3, as
examples. A mission maker looking for one of the other 31 finds nothing and concludes, as Tripack
did, that Lua is required.

The 34, grouped the way a mission maker thinks about them rather than the order they appear in the
script:

- **Who gets rescued** — `enableForAI`, `enableForRED`, `enableForBLUE`, `csarOncrash`,
  `countCSARCrash`, `allowDownedPilotCAcontrol`
- **Who can fly the rescue** — `enableAllslots`, `useprefix`, `enableSlotBlocking`, `max_units`
- **Lives and sanctions** — `csarMode`, `maxLives`, `reenableIfCSARCrashes`,
  `disableAircraftTimeout`, `disableTimeoutTime`, `destructionHeight`
- **Finding the survivor** — `coordtype`, `coordaccuracy`, `autosmoke`, `bluesmokecolor`,
  `redsmokecolor`, `radioSound`, `requestdelay`, `messageTime`
- **Picking them up** — `loadDistance`, `extractDistance`, `pilotRuntoExtractPoint`, `loadtimemax`,
  `weight`, `allowFARPRescue`
- **The survivor's own state** — `immortalcrew`, `invisiblecrew`, `downedPilotCounterRed`,
  `downedPilotCounterBlue`

### What done means

- A table in the CSAR section of the guide: setting, default, one line of effect. The default comes
  from `CSAR.lua`, read at the time of writing, not from memory.
- The table says plainly which settings are **not** reachable this way and why. Today the guide
  says "complex settings" without saying which, which is how a plain boolean got mistaken for one.

  **Corrected while writing it — this ticket had it wrong.** Only `aircraftType` is a table of
  tables: `CSAR.lua:21` opens it empty and fills it by key (`csar.aircraftType["UH-1H"] = 8`).
  `csarFixedUnits` (line 36), `bluemash` (129) and `redmash` (142) are **flat lists of strings**,
  exactly like `csarPrefix`, so after ticket 01 they are written in YAML like any other list. So the
  count is 34 scalars **plus 4 lists reachable from YAML**, and **one** setting that is not.
- `csarPrefix` is documented according to what ticket 01 delivered, not according to what the
  current example claims.
- FR and EN ship together, the page keeps its explicit English anchors, and
  `poetry run docs-check` passes.
- `services/support-bot/scripts/refresh_doc_pages.py` is re-run and its output committed —
  `docs-check` does not catch that, and the service's own CI job does.

### What not to do

Do not generate the table from `CSAR.lua` at build time. It is a vendored third-party script whose
comments are uneven (`weight`, `loadtimemax` and the two counters carry none), and half the value
here is a sentence written for a mission maker rather than the author's own note to self. Write it
by hand, once, and let the ratchet catch it if the script changes.

---
