# FIX-MODULE-SETTINGS-OVERWRITTEN — a module default silently overwrites `module_settings:`

Status: ✅ done — shipped in 6.15.32

Found on 2026-08-22, auditing the DCS session checks for whether they could conclude. This one could
not — and it would have reported a verdict anyway.

## The defect

`lua_config_generator` emits, unconditionally, for any mission with Skynet enabled:

```lua
veafSkynet.DynamicSpawn = false        -- from `dynamic_spawn`, absent means false
veafSkynet.initialize(true, false, false, false)
```

A mission that sets the same variable through the `module_settings:` hatch gets it written **earlier** in
the file, so the default wins:

```lua
-- ── Module settings ──
veafSkynet.DynamicSpawn = true         -- line 19, from module_settings
...
veafSkynet.DynamicSpawn = false        -- line 164, right before initialize()
```

No warning. The mission author reads their setting in the generated Lua and it is there — 145 lines above
the line that undoes it.

## Who it broke, which is the part worth keeping

`test/veaf-tools/verify-mission-c`, **the mission whose job is to verify this very feature**. Its yaml
carried a note claiming the hatch worked *"because it lands in the generated Lua BEFORE
veafSkynet.initialize()"* — true when written, false since 2026-08-20 (`eb29820b`, PR #767, the lot that
introduced the `dynamic_spawn` field).

So checks 6 and 7 of that mission would have run with the feature **off**, measuring the documented
default and reporting it as a result. The session plan even warned *"rebuild it before the session or the
run measures 6.15.7"* and nobody acted on it. Caught by reading the config the build actually produced
rather than the yaml that was meant to produce it.

## Scope: exactly one field, and the right shape is already in the file

An enumerated sweep of every Lua module variable the generator assigns found **three**, and the other two
are already guarded the correct way:

| Emitted | Guard |
|---|---|
| `veaf.SecurityDisabled` | `if "disabled" in security_cfg` — written only when actually given |
| `veafSecurity.password_MM` | `if mm_hashes` — written only when there is something to write |
| `veafSkynet.DynamicSpawn` | **none** — always written, default included |

So this is not a family, and the fix is not a design question: the correct pattern sits fifteen lines
above the defect in the same file.

## Definition of done

- [ ] `veafSkynet.DynamicSpawn` is emitted only when `dynamic_spawn` is explicitly present in the
      `SKYNET:` block, matching how `SecurityDisabled` is already handled
- [ ] A `module_settings:` key that a module block would overwrite is **reported** at build time. Silence
      is what made this expensive: the setting was visibly present and inert
- [ ] Regression test on the generated Lua: with `module_settings: {veafSkynet.DynamicSpawn: true}` and no
      `dynamic_spawn` field, the value reaching `initialize()` is `true`
