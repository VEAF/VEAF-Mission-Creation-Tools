# 01 — Emit the module default only when the field is given

Status: ⬜ ready

## What

In `lua_config_generator.py` (~line 1610), `veafSkynet.DynamicSpawn` is written from
`skynet_cfg.get("dynamic_spawn", False)` on every build. Write it only when `"dynamic_spawn" in
skynet_cfg`, the way `veaf.SecurityDisabled` is already handled at line 1412 of the same file.

## Careful about

Skynet's own default must stay `false`, and it already is — `veafSkynet.lua` declares
`veafSkynet.DynamicSpawn = false`. Not emitting the line leaves that default in place, so nothing
changes for a mission that never mentions the field. That is why this fix is safe rather than a
behaviour change.

## Done when

- [ ] With `dynamic_spawn: true` → the line is emitted as `true` (unchanged)
- [ ] With `dynamic_spawn: false` → the line is emitted as `false` (unchanged; an explicit off is a
      statement and must survive a `module_settings` that says otherwise)
- [ ] With the field absent → **no line at all**, so a `module_settings:` value survives
- [ ] A generated-Lua test pins all three
