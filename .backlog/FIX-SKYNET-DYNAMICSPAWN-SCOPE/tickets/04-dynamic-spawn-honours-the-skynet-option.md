# 04 — `dynamic_spawn` must honour the spawn's `skynet` option

Status: ✅ done
Type: fix

Not in the original PRD. Found on 2026-08-20 by taking David's question seriously — *"on a une option
pour dire si on veut que le sam soit attaché à IADS ou pas, non ?"* — and going to check what that
option does on the `dynamic_spawn` path. Answer: nothing at all.

## The defect

`skynet` is a per-spawn option ([`veafSpawnParser.lua:45`](../../../src/scripts/veaf/veafSpawnParser.lua:45)):
`true`, `false`, or a network name. It is consumed in
[`veafSpawnCore.lua:429`](../../../src/scripts/veaf/veafSpawnCore.lua:429):

```lua
if veafSkynet and not veafSkynet.DynamicSpawn and options.skynet then
```

— and the comment on that line states the intent plainly:

> only add static stuff like sam groups and sam batteries, **not mobile groups and convoys** — and do
> not do that if DynamicSpawn is active in VeafSkynet

But `OnDynamicSpawn` ([`veafSkynetIadsHelper.lua:500`](../../../src/scripts/veaf/veafSkynetIadsHelper.lua:500))
takes a raw DCS birth event. It has no access to `options`, never asks, and adds **any** eligible group
to its coalition's default network (`:537`). So with `dynamic_spawn` on, the global handler overrides
the per-spawn instruction, and the static-vs-mobile distinction the shortcuts encode is lost.

## Measured, not supposed

`-hv_convoy_red` passes `skynet false` explicitly
([`veafShortcuts.lua:1013`](../../../src/scripts/veaf/veafShortcuts.lua:1013)). Its group, in
`veaf-units.yaml:632`, contains `Tor 9A331`, `2S6 Tunguska` and `Strela-10M3`. The first two are in
Skynet's own database (`src/scripts/community/skynet-iads-compiled.lua`), as is the
`ZSU-23-4 Shilka` of `attack_convoy_red`. `isGroupUsable` defaults to
`GroupIntegrationModes.Lenient` (`:57`), where **one** eligible unit is enough (`:574-581`).

So with `dynamic_spawn` on, an attack convoy joins the IADS against its own declaration. Same family as
#261 and #290: a global setting overriding a per-call option.

## The shape of the fix

The spawn knows the intent; the birth handler does not. The intent has to travel.

- `veafSpawnCore` records what it is about to spawn and what `skynet` said for it, in a table keyed by
  group name, before the group is created
- `OnDynamicSpawn` consults it: `skynet false` means skip; a network **name** means use that network
  rather than the coalition default (`:522` currently always takes the default, so this also fixes
  named networks being ignored on the dynamic path)
- an entry is consumed once, so the table does not grow across a long mission
- a group nobody declared — placed in the Mission Editor, spawned by a third-party script — keeps
  today's behaviour and joins the coalition default. That is the whole point of `dynamic_spawn` and
  must not regress

## Watch for

Do not fix this by re-enabling the `veafSpawnCore` branch at `:429` when `dynamic_spawn` is on: that
would integrate the group **twice** by two paths. Keep the exclusivity, move the decision.

## Definition of done

- [ ] With `dynamic_spawn` on, a group spawned with `skynet false` does **not** join any network
- [ ] With `dynamic_spawn` on, `skynet <network name>` joins that network, not the coalition default
- [ ] A group nobody declared still joins the coalition default (regression — that is the feature)
- [ ] No group is integrated twice
- [ ] Lua tests for all four cases above
