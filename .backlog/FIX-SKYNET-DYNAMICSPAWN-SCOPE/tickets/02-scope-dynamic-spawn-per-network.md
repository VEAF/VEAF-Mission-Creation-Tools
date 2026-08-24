# 02 — Deactivating one network must not disarm the other

Status: ✅ done
Type: fix

Half of [#261](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/261), and the half MacFlorent
explicitly parked: *"since `DynamicSpawn` is global to the module, this will set it to off globally,
but for now we will live with that"*. This ticket is the "not for now".

## The defect, visible in one line

[`veafSkynetIadsHelper.lua:1179`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:1179), inside
`deactivateNetwork`:

```lua
veafSkynet.monitorDynamicSpawn(false)
iads:deactivate()
```

`monitorDynamicSpawn` removes the **one** mist event handler shared by every network
(`veafSkynet.monitorDynamicSpawnHandlerId`, `:498`). So deactivating the red network stops dynamic
integration for **blue** as well — and nothing turns it back on, because `monitorDynamicSpawn(true)`
is only ever called once, from `_initialize` (`:1057`).

Symmetrically, `veafSkynet.DynamicSpawn` is a single module-level boolean: "on for blue, off for red"
cannot be expressed at all.

## The shape of the fix

The handler stays **armed**, and the decision moves to where the network is known:

- carry the flag **per network**, in `veafSkynet.structure[networkName]` — the table already holds
  `coalitionID`, `includeInRadio`, `debugFlag`, `groups` and `iads` (`:916-922`), so it is the natural
  home
- `veafSkynet.DynamicSpawn` keeps working as the value each network is **created with**, so ticket 01's
  YAML field and the `module_settings` hatch both keep meaning what they mean
- `OnDynamicSpawn` (`:500`) already resolves the group's network by coalition (`:522`) before doing
  anything — that is the point where it asks whether *that* network wants dynamic integration, and
  returns if not
- `deactivateNetwork` clears the flag for its own network only, and stops calling
  `monitorDynamicSpawn(false)`
- keep `monitorDynamicSpawn` as the arming primitive: it is armed if **any** network wants it

## Watch for

`OnDynamicSpawn` runs on **every unit birth in the mission** once armed. Whatever the per-network
lookup costs, it must be cheap and must not raise before the early returns at `:501-519` have run —
that guard chain is what keeps the handler from doing work per unit instead of per group.

## Definition of done

- [ ] `dynamic_spawn` is per network, not module-wide
- [ ] Deactivating red leaves blue's dynamic integration armed and working
- [ ] `monitorDynamicSpawn(false)` no longer fires from `deactivateNetwork`
- [ ] Lua tests: two networks × two flag states, and "deactivate red, spawn into blue, blue integrates"
