# 02 — The Fat Cow in the demo mission, before the next release

Status: ✅ done (VEAF/VEAF-Demo-Mission-v6#12, 2026-10-29)

Zip, 2026-10-27: do it before the next VMCT release (`CLAUDE.md` §9.9).

## Done when

- `VEAF/VEAF-Demo-Mission-v6` has a `tour/steps.yaml` step for the Fat Cow: a CH-47F loads a Fat Cow loadout in a logistic zone, lands and deploys its FARP, an Apache (or a Ka-50) rearms and refuels there; the step's acceptance check says what is seen.
- The same step, or the CSAR one, shows the CSAR menu in the CH-47F.

## Depends on

- CTLD's Fat Cow merged and released (VEAF/CTLD#273), and VMCT vendoring that release: VMCT embeds CTLD rc13 today, which has no Fat Cow.

## Done

[VEAF/VEAF-Demo-Mission-v6#12](https://github.com/VEAF/VEAF-Demo-Mission-v6/pull/12), built with `develop` (CTLD rc15): a `Kutaisi CH-47F` slot, `ctld-config.yaml` to 2.3.0 (`mission ctld-upgrade`), step 22 "Fat Cow : la FARP du CH-47F" and the CH-47F in the CSAR step.
Bridge probes green: an AI CH-47F opens its FARP with exactly its stock, GRASS leaves it alone, CSAR lists the CH-47F.
In game (Zip, solo): the CH-47F loads and deploys its FARP, which stays open when the pilot changes slot.
Not seen in game: an AH-64D rearming from the cow's FARP, which needs flying; it stays in the demo's recette.
DCS parks the CH-47F on helicopter stand 58 at Kutaisi, 1.6 km from the airfield's 250 m logistic circle, whatever stand `add_air_group` asks for: the player hops into the circle before loading.
