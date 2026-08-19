# FEAT-RADIO-BEACONS — no VEAF command spawns a radio beacon

Status: ⬜ ready

Origin: [#38](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/38) (FM beacons) and
[#192](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/192) (`-beacon` through CTLD) —
same mechanism, and #192 already points at the implementation.

## The gap

No VEAF beacon command exists. `ctld.spawnRadioBeaconUnit` is *mentioned* at `veafGrass.lua:1349` as
having **no public equivalent**, which is exactly the hole both issues describe. `-tacan` exists and
is the model #192 names.

## Scope

A `-beacon` marker command on the `-tacan` model, spawning through CTLD 2 — which is now properly
initialised (`FIX-CTLD-NEVER-INITIALIZED`), so the dependency is sound in a way it was not when #192
was filed.

**Settle one thing first**: whether CTLD 2 still exposes beacon spawning the way CTLD 1 did. That
comment in `veafGrass.lua` predates the CTLD 2 migration and may describe a world that no longer
exists — the same trap that made #72's first verdict wrong.

## Definition of done

- [ ] A marker command spawns a radio beacon, FM included (#38's ask)
- [ ] CTLD 2's real beacon API checked rather than inferred from a stale comment
- [ ] Documented on the spawn page, both languages
