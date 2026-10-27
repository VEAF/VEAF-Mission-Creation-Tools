# 02 — The Fat Cow in the demo mission, before the next release

Status: ⬜ ready (blocked on CTLD's Fat Cow being released and vendored)

Zip, 2026-10-27: do it before the next VMCT release (`CLAUDE.md` §9.9).

## Done when

- `VEAF/VEAF-Demo-Mission-v6` has a `tour/steps.yaml` step for the Fat Cow: a CH-47F loads a Fat Cow loadout in a logistic zone, lands and deploys its FARP, an Apache (or a Ka-50) rearms and refuels there; the step's acceptance check says what is seen.
- The same step, or the CSAR one, shows the CSAR menu in the CH-47F.

## Depends on

- CTLD's Fat Cow merged and released (VEAF/CTLD#273), and VMCT vendoring that release: VMCT embeds CTLD rc13 today, which has no Fat Cow.
