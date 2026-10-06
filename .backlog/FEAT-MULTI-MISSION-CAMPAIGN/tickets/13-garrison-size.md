# 13 — Garrisons of a sensible size

Status: ✅ done

David's first test campaign, 2026-10-06: 41 to 96 units per zone, about 750 ground units for 12 zones, and one capture spent red's whole reserve.

Measured with the real spawn data, 40 draws per setting (red; blue alike):

| setting | through `generateCasGroup` | composed by the campaign |
|---|---|---|
| outpost, first cut (2/1/1) | 49 (20 – 75) | 27 |
| airfield, first cut (4/3/2 + LR SAM) | 119 (79 – 168) | 79 |
| **outpost, shipped (1/1/1)** | 36 | **23 (12 – 36)** |
| **airfield, shipped (1/3/2 + LR SAM)** | 67 | **51 (35 – 74)**, ≈ 20 of it the SAM |

`generateCasGroup` always adds a transport company of 10 to 15 lorries and spreads the target over `(size + spacing) * 350` m. David chose "b" (2026-10-06): the campaign composes its garrison from the unit generators, without the transport company and within the zone's radius, with the smaller classes. The example campaign goes from about 1 080 ground units to about 470.

## Done when

Tests cover the groups composed (sections, platoons, air defence groups, no transport company) and their placement within the zone's radius; the shipped classes and the page give the measured counts.
