# FIX-CAPTURE-ZONE-MEMBERSHIP — a convoy takes a zone without becoming its garrison: two definitions of "in the zone"

Status: ⬜ ready

## Found

David, 2026-10-08, *Kolkhida* mission 1, built from `develop` at `4ab6bd0d` (with FIX-ASSAULT-CONVOY-FINDINGS ticket 03's measurement): "Poti n'a pas absorbé le convoi".

The logging shipped by FIX-ASSAULT-CONVOY-FINDINGS ticket 03 gives the cause:

```text
17:36:13 CAMPAIGN absorbConvoy: zone [Poti] taken by blue: 2 assault convoy record(s) to look at
17:36:13 CAMPAIGN absorbConvoy: zone [Poti]: convoy [Kobuleti - Poti assault] of blue, ended nil, group exists, 9 unit(s) alive, 0 inside, nearest 2117 m from the centre (radius 2000)
17:36:13 CAMPAIGN capturedBy: zone [Poti]: no assault convoy of blue in it, its garrison is drawn from the reserve
17:36:13 CAMPAIGN drawGarrison: zone [Poti]: garrison drawn, 24 unit(s)
```

The capture before it was run by the convoy's own units (`held by blue (Kobuleti - Poti assault - MBT Merkava IV #5)`, `… ATGM VAB Mephisto #9`, `… Truck M939 Heavy #8`, `… SPAAA Vulcan M163 #10`).

Measured right after, in the running mission through the fiddle hook (read-only): `world.searchObjects(Object.Category.UNIT, SPHERE { point = Poti's centre (y = 0), radius = 2000 })` returns the convoy's 9 units at **2036 to 2077 m** from the centre, 2D and 3D alike (units at y = 5 m).

## Causes

1. **Two definitions of "in the zone".** `VeafCampaignZone:sidesPresent` (the capture) trusts `world.searchObjects` on a sphere, which returns units up to about 4 % beyond its radius; `veafCampaign.absorbConvoy` measures the exact 2D distance. A convoy standing just outside the radius takes the zone, and is then not found in it: the zone draws a garrison from the reserve and the convoy stays "on the road".
2. **The convoy stops at the zone's edge.** All nine units halted together between 2.04 and 2.08 km from Poti's centre, not at the centre the campaign sends them to (`veafNamedPoints` "CAMPAIGN Poti"). Not explained yet: the road's end, the convoy's destination handling, or something stopping it on arrival.

Same picture on the earlier run of the day (FIX-ASSAULT-CONVOY-FINDINGS): measured after the fact, the units stood 0–90 m from the centre — they had driven on after the capture.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-one-definition-of-in-the-zone.md) | One definition of "in the zone" for the capture and the absorption | ⬜ |
| [02](tickets/02-convoy-drives-into-the-zone.md) | The assault convoy drives into the zone, not to its edge | ⬜ |
| [03](tickets/03-searchobjects-overshoots.md) | `world.searchObjects` overshoots its sphere: a DCS trap, measured | ⬜ |

## Related

- `FIX-ASSAULT-CONVOY-FINDINGS` (#1108), ticket 03: the measurement that found this.
- `FEAT-OPPOSITION-SCALES-WITH-PLAYERS` ticket 04 (#1100): the assault convoys.
