# 05 — A weapon is never a threat

Status: ⬜ ready

Measured on the same convoy (fiddle hook, read-only): its threat list holds `weapons.shells.M61_20_HE_gr strength=inf at 3697 m from Poti`. The hit event path records the weapon object, not the unit that fired it. Counted for an infinite strength, such an entry can make a convoy fall back for nothing.

- Record the shooter (the weapon's launcher), or nothing when it cannot be resolved; never a `Weapon` object.
- Lua tests: a hit whose initiator is a shell records the firing unit, or no threat; a convoy is not made to fall back by it.
