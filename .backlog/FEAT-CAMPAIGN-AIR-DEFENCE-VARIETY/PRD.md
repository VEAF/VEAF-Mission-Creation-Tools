# FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY — every air defence DCS offers, red's medium range first

Status: 🧑 waiting-human

David, 2026-11-21, after the evening on the Campagne server: "il faudrait s'assurer qu'on a tous les SAM possibles. Par exemple, on ne spawn jamais de Tor M2."

## Measured (2026-11-21)

Every missile air defence vehicle of `dcsUnits.yaml` (category `Air Defence`, attribute `AA_missile`), against what the campaign's zones draw: the generated defences `generateAirDefenseGroup-<SIDE>-<N>` of `veaf-units.yaml`, the escorts of `veafCasMission.lua` (lines 640-730), the long-range batteries `veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS` and the shop's upgrades `veafCampaignEconomy.UPGRADES`.

| System | Has a VEAF group | Drawn by the campaign |
|---|---|---|
| Tor M1 (`Tor 9A331`), Tunguska, SA-8, Strela-1, Strela-10, HQ-7B | yes | yes, short range |
| SA-10, SA-5 | yes | yes, the long-range battery of a modern era (`long_range_sam`) |
| Hawk, NASAMS AIM-120C, Patriot, Roland, Chaparral, Avenger, Linebacker | yes | yes, blue |
| **Tor M2** (`CHAP_TorM2`) | `sa15m2_squad` | **no** |
| **Pantsir S1** (`CHAP_PantsirS1`) | `sa22_squad` | **no** |
| **SA-6** (`Kub 2P25 ln`), **SA-11** (`SA-11 Buk LN 9A310M1`), **SA-3** (`5p73 s-125 ln`) | `sa6`, `sa11`, `sa3` | **no** |
| SA-2 (`S_75M_Volhov`) | `sa2` | cold war long range only |
| Rapier (`rapier_fsa_launcher`), NASAMS AIM-120B | `rapier_radar`, `rapier_optical`; NASAMS B | no |
| **IRIS-T SLM** (`CHAP_IRISTSLM_LN`, `_STR`, `_CP`) | **no** | no |

Red therefore has **no medium-range SAM at all**: short range everywhere (about 12 km at most), and one SA-10 or SA-5 where `long_range_sam` is set (Hama on Oronte). The air defence lines of the Campagne server's `dcs.log` on 2026-11-21 (`[CAMPAIGN AIRDEF]`) show no Kub, Buk or S-125 in any red zone.

The Tor M2, the Pantsir S1 and the IRIS-T SLM come from the Currenthill Assets Pack, installed with DCS under `CoreMods/tech/Currenthill Assets Pack` (measured in `C:\jeux\DCS World`): every player has it, no module to buy.

## Decided

David, 2026-11-21: a, b and c.

- **a.** Red's short range draws the Tor M2 and the Pantsir S1 too, in the modern era. Ticket 01.
- **b.** Red gets a medium-range SAM: a zone option like `long_range_sam`, capped and spaced. Ticket 02.
- **c.** Blue's air defence: a VEAF group for the IRIS-T SLM, and the Rapier and the IRIS-T in the shop's upgrades. Ticket 03.

Not taken: (d) changing nothing.

`veafCasMission`'s tables serve every VEAF mission, not only the campaign: a change to the generated levels shows in the Open Trainings' CAS missions too. That is wanted, and the PR says so.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [Red's short range draws the Tor M2 and the Pantsir](tickets/01-red-short-range-tor-m2-pantsir.md) (a) |
| 02 | [A medium-range SAM for red](tickets/02-red-medium-range-sam.md) (b) |
| 03 | [The IRIS-T SLM and the Rapier for blue](tickets/03-blue-iris-t-and-rapier.md) (c) |

## Done

The three tickets are implemented in one pull request into `feature/dynamic-campaign`. What is left is the in-game check of each ticket, on the Campagne server after a rebuild, with `medium_range_sam` set on two or three red zones of the Oronte campaign by the control session.
