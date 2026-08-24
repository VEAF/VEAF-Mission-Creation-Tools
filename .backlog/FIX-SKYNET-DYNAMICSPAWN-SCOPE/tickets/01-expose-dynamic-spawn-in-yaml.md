# 01 — `dynamic_spawn` becomes a `mission.yaml` field

Status: ✅ done
Type: fix

Closes the half of [#151](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/151) that the
verification session actually found.

## Why this is the whole of #151

The issue reads *"combat-zone SAMs are not in the IADS"*, and the DCS session of 2026-08-18 showed the
path **works**: a standard DCS SA-6 spawned by a combat zone does join the red network. Sharko's
mission simply had the flag off — and there is no way to turn it on.

`veafSkynet.DynamicSpawn` is declared at
[`veafSkynetIadsHelper.lua:72`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:72) and read once, at
the end of `_initialize` (`:1057`). Nothing in the `modules:` schema reaches it. The only way today is
the migration hatch:

```yaml
module_settings:
  veafSkynet.DynamicSpawn: true
```

which exists to carry v5 missions across, not to configure a module.

## What ships

`dynamic_spawn` in the extended form of the `SKYNET` module, beside the keys that already live there:

```yaml
modules:
  SKYNET:
    enabled: true
    dynamic_spawn: true
```

- default stays **`false`** — it arms a birth-event handler on every spawn in the mission, so turning
  it on is a choice, not a default
- add it to the `registerModule` defaults table (`:1229`) and read it in the module callback, the same
  way `include_red_in_radio` is handled
- `src/defaults/mission-folder/mission.yaml` gets the key in the commented extended form, per the
  defaults-lockstep rule
- document it on the `veafSkynetIadsHelper` page in **both** languages, with what it costs and what it
  buys

## Worth documenting while here

The two integration paths are **mutually exclusive**, and nothing says so today.
[`veafSpawnCore.lua:429`](../../../src/scripts/veaf/veafSpawnCore.lua:429) reads:

```lua
if veafSkynet and not veafSkynet.DynamicSpawn and options.skynet then
```

So with `dynamic_spawn` on, the spawn no longer integrates the group itself — the birth handler does.
That is why the flag looks inert when you go looking for it from the spawn side. See ticket 04, which
is the consequence of this exclusivity.

## Definition of done

- [ ] `dynamic_spawn` settable from `mission.yaml`, default `false`
- [ ] Present in `src/defaults/mission-folder/mission.yaml`
- [ ] Documented FR + EN on the `veafSkynetIadsHelper` page, cost included
- [ ] Python test asserting the key reaches the generated `veaf-config.lua`
