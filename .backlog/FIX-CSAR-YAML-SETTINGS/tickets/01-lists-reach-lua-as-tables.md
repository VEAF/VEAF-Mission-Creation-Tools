# 01 — A list in settings reaches Lua as a table

Status: ✅ done

## What is wrong

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

## What done means

- A YAML list generates a Lua table literal: `{ "helicargo", "MEDEVAC" }`, each element quoted
  through the existing string helper so a value carrying a quote or a newline stays safe.
- A nested list is **handled**, not refused: the renderer is recursive, so nesting costs no extra
  code path, and refusing it would.  Decided here rather than left open.
- A mapping is **refused** with a message naming the module and the key, rather than written as a
  string. There is no evidence any consumer wants one, and silence is what caused this ticket.
- Tests assert the generated Lua text for each type: bool, int, float, string, list of strings,
  list of numbers, mapping (refusal), and a string containing a quote.

## Why this before the documentation ticket

Ticket 03 has to state whether `csarPrefix` can be set from `mission.yaml`. Today the honest answer
is "no, and trying produces nonsense". After this ticket it becomes "yes, as a list". Documenting
first would mean writing the wrong answer down.
