# 02 — Report a `module_settings:` key a module block overwrites

Status: ⬜ ready

## What

Ticket 01 fixes the one field this was found on. This one removes the *class* of the problem: whenever a
`module_settings:` key names a variable a module block also writes, say so at build time.

The cost here was never the wrong boolean — it was that the setting looked applied. It appeared in the
generated Lua, in the file the author would open to check, 145 lines above the line that undid it.

## Done when

- [ ] The build reports a `module_settings:` key shadowed by a module block, naming both and which value
      wins
- [ ] It is a warning, not an error: shadowing is legitimate while a hatch is being migrated away from
- [ ] Tested on the real case — `veafSkynet.DynamicSpawn` in `module_settings` alongside
      `SKYNET: {dynamic_spawn: ...}`
