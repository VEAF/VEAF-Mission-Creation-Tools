# 02 — One module's init error stops the whole config

Status: ✅ done
Type: fix (resilience)
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py` (module init blocks, e.g. `veaf.ctld_initialize()` at l. 2164), tests

## What happens

`veaf-config.lua` initialises the modules one after the other with no protection.
When one raises, the rest of the file never runs, and the only trace is one `Mission script error` line naming the module's own file — not the modules that were lost with it.

## Measured

Demo mission in DCS, 2026-10-05 (ticket 03 as the trigger): CTLD's init raised; probed by `dcs-bridge` 43 s in: 0 combat zones registered, the `#veafInterpreter` carriers still standing as single units (3 instead of 18 for the SA-11 site), no QRA, assets, sanctuary or Skynet configuration. Only the separate custom script (the guided tour) loaded.

## Fix

Wrap each module's init block in a `pcall` that logs `"<MODULE> init failed: <err>"` at ERROR and lets the next module start.
Test: a config whose middle module raises still initialises the modules after it, and the log names the failing module.

## Note

This does not hide the error: ticket 03's CTLD failure would still be logged, but the mission would keep its zones, QRA and IADS.
