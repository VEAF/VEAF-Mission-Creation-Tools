# 03 — `lua` action (named-function reference) + build-time verification

Status: ✅ done

## Context

The escape hatch (ADR 0011): a menu item may bind a command to a Lua function the
maker defines in `mission-script.lua`, **by name** — never inline code:

```yaml
- { command: "Mon script", action: lua, function: "maMission.doStuff", args: [1, "x"] }
```

The menu stays declared in YAML; the function lives in the maker's Lua. A reference
with no matching definition must **fail the build** (not silently drop the command).

## Tasks

- [ ] Dispatch: `action: lua` emits `veafRadio.command(label, <function>, <args>)`
      with the referenced function symbol and literal `args`.
- [ ] Build-time check: scan the mission Lua (`mission-script.lua` and any injected
      scripts) for the referenced function definition, reusing / extending
      `lua_module_scanner.py`. Missing symbol → build error naming the function and
      the menu item.
- [ ] Support dotted symbols (`table.func`) and plain globals; document the matching
      rule (definition present, not merely a call site).

## Definition of Done

- A valid `lua` reference emits the command; a dangling reference fails the build
  with a clear message.
- Unit tests: resolves an existing function, fails on a missing one, handles dotted
  names and `args`.
- Quality ratchet + coverage gate obligations (see PRD).
