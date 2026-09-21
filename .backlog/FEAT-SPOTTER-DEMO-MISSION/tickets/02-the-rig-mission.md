# 02 — The rig mission, and its geometry

Status: ✅ done

`test/veaf-tools/demo-spotter-network/`, Syria, anchored on the empty-desert point where DCS
reliably processes events. Full reasoning in
[its README](../../../test/veaf-tools/demo-spotter-network/README.md).

## The geometry, and why each distance is what it is

| Distance | Why |
|---|---|
| target → `SpotterIgla` = **8 km** | under the Igla's 10 km of eyes |
| `SpotterIgla` → `NetworkSa6` = **10 km** | under the 20 km radio range |
| target → `NetworkSa6` = **18 km** | inside a Kub's firing envelope (~24 km) |
| `ControlSa6` at **60 km** | three times the radio range: unreachable by construction |

**The spotter is an `SA-18 Igla-S manpad`, and that is measured rather than chosen.** The profile
lookup in `veafSkynet.SpotterUnitTable` takes the **first** matching row, and `SAM elements`
(range 0, blind) comes before `MANPADS` (10 km). Resolved against `dcsUnits.lua`:

| Unit | First row it matches | Range |
|---|---|---|
| `SA-18 Igla-S manpad` | `MANPADS` | **10 000 m** |
| `Kub 1S91 str`, `Kub 2P25 ln` | `SAM elements` | 0 — blind, relays only |
| `ZSU-23-4 Shilka`, `Roland ADS` | `SAM elements` | 0 — **unusable as spotters** |
| `Ural-375` | `Unarmed vehicles` | 3 000 m |

The last two rows are the trap: an air-defence vehicle looks like the obvious forward observer and is
blind.

## The last line of defence is off, on purpose

With it on, a dark site keeps a radius drawn **at random between 10 and 15 km**, and `NetworkSa6`
sits 18 km from the target. The verdict would then depend on a dice roll made at mission start. A rig
whose verdict comes from a draw is not a rig.

## Definition of done

- [x] `veaf-tools mission validate .` clean, the mission builds.
- [x] The bridge is injected and present in the built `.miz`.
- [x] `security.disabled: true` at the root — the bridge drives this with nobody at the keyboard.
- [x] No `build:` block committed: a build writes an absolute `scripts_path` into it.
- [x] The built `.miz` carries `getSpotterWakeUpLog` and `LastLineOfDefence = false`, read back out
      of the archive rather than trusted from the yaml.
