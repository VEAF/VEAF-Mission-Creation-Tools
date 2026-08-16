# 01 — Generate the CTLD start-up call in `veaf-config.lua`

Status: ✅ done 2026-08-16 — emitted before the module block; verified end to end on a real build (CTLD line 26, veafGrass 190, veafAssets 200)
Type: fix
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `test/python/test_lua_config_generator*.py`

## The change

The generator emits a start-up block for CTLD, the way it already does for Skynet, CSAR and TUM:

```lua
-- ── CTLD 2 ───────────────────────────────────────────────────────────────────
if ctld then
    veaf.ctld_initialize()
end
```

Emitted only when `_community_enabled(mission_yaml, "ctld")` is true — the same rule the builder uses
to decide whether `CTLD.lua` is injected at all, so the call can never target an absent script. The
`if ctld then` guard stays anyway: a mission can ship its own CTLD through `custom_scripts`.

## Where it goes, and why not with the other external modules

**Before** the `-- ── Module configuration + initialization ──` section, not in the
`-- ── External modules ──` block at the end of the file.

`veaf.registerModule` gives CTLD order 50, ahead of `veafGrass` (150) and `veafAssets` (160) — the
two VEAF modules that call into CTLD. The generated file has no such ordering: it runs top to bottom.
Emitting the call after `veafGrass.initialize()` would reproduce, in the generated file, exactly the
ordering the framework was designed to prevent.

## Tests

- `ctld` enabled (and absent from `community_scripts`, i.e. the default): the generated file contains
  `veaf.ctld_initialize()`, and its line index is **lower** than the first `veafGrass.initialize()`
  / `veafAssets.initialize()` line. Ordering is the point of the ticket, so the test pins the order,
  not just the presence.
- `ctld` disabled via `community_scripts`: no `veaf.ctld_initialize()` line, and the existing
  `veaf.setConfig("ctld", "enable", false)` line is unaffected.

## Done when

The two tests pass, and a mission built from `src/defaults/mission-folder` produces a
`veaf-config.lua` whose CTLD call precedes the module initialisation block.
