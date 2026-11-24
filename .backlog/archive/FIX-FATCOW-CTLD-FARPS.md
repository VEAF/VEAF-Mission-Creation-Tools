# FIX-FATCOW-CTLD-FARPS — GRASS leaves CTLD's Fat Cow FARPs alone, and the CH-47F gets CSAR

Status: ✅ done (2026-10-29) · archived 2026-11-24

Origin: the evening server run of CTLD's Fat Cow (VEAF/CTLD#273, Privé 1, 2026-10-26, Zip, Griffin, Paluche), findings 3 and 5 of its ticket 06.

## Problem

- **GRASS made a Fat Cow unlimited.** A Fat Cow is a CH-47 that opens a FARP whose warehouse holds what the cow carries. `veafGrass.onBirth` calls `fillAllFarpWarehouses` on every player birth, which refills every FARP, the cow's included: two packs read back 50 035 and 50 055 kg of fuel from a cow that carried 7 200.
- **No CSAR menu in the CH-47F.** `csar.aircraftType` lists no `CH-47Fbl1`, so CSAR gives the Chinook no menu in any VMCT mission.

## Change

- `veafGrass.fillAllFarpWarehouses` skips any airbase whose name starts with `CTLD_`: CTLD names its Fat Cow FARPs `CTLD_FatCow_FARP_<n>` for this. CTLD also guards its own stock since #273, but a refill run before CTLD reads hides what was taken since its last read.
- `csar.aircraftType["CH-47Fbl1"] = 24`, a VEAF adaptation of the vendored `CSAR.lua`, recorded in `vendored.yaml`.

## Tickets

- [01 — GRASS skips CTLD FARPs, CH-47F in CSAR](FIX-FATCOW-CTLD-FARPS.md)
- [02 — The Fat Cow in the demo mission, before the next release](FIX-FATCOW-CTLD-FARPS.md)

## Tickets, in full

## 01 — GRASS skips CTLD FARPs, CH-47F in CSAR

Status: ✅ done (#1202)

### Done when

- `fillAllFarpWarehouses` never refills an airbase named `CTLD_…` (test `TestVeafGrassFillAllSkipsCtldFarps`).
- `csar.aircraftType["CH-47Fbl1"]` is 24, and `vendored.yaml` lists it among the CSAR adaptations to re-apply.
- In game, with a CTLD build carrying the Fat Cow: a player joining does not refill a deployed cow's FARP, and the CH-47F has the CSAR menu (to check by Zip with CTLD's ticket 06).

## 02 — The Fat Cow in the demo mission, before the next release

Status: ✅ done (VEAF/VEAF-Demo-Mission-v6#12, 2026-10-29)

Zip, 2026-10-27: do it before the next VMCT release (`CLAUDE.md` §9.9).

### Done when

- `VEAF/VEAF-Demo-Mission-v6` has a `tour/steps.yaml` step for the Fat Cow: a CH-47F loads a Fat Cow loadout in a logistic zone, lands and deploys its FARP, an Apache (or a Ka-50) rearms and refuels there; the step's acceptance check says what is seen.
- The same step, or the CSAR one, shows the CSAR menu in the CH-47F.

### Depends on

- CTLD's Fat Cow merged and released (VEAF/CTLD#273), and VMCT vendoring that release: VMCT embeds CTLD rc13 today, which has no Fat Cow.

### Done

[VEAF/VEAF-Demo-Mission-v6#12](https://github.com/VEAF/VEAF-Demo-Mission-v6/pull/12), built with `develop` (CTLD rc15): a `Kutaisi CH-47F` slot, `ctld-config.yaml` to 2.3.0 (`mission ctld-upgrade`), step 22 "Fat Cow : la FARP du CH-47F" and the CH-47F in the CSAR step.
Bridge probes green: an AI CH-47F opens its FARP with exactly its stock, GRASS leaves it alone, CSAR lists the CH-47F.
In game (Zip, solo): the CH-47F loads and deploys its FARP, which stays open when the pilot changes slot.
Not seen in game: an AH-64D rearming from the cow's FARP, which needs flying; it stays in the demo's recette.
DCS parks the CH-47F on helicopter stand 58 at Kutaisi, 1.6 km from the airfield's 250 m logistic circle, whatever stand `add_air_group` asks for: the player hops into the circle before loading.
