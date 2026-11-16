# 12 — Resources for the AI: one stock per side, prices, production

Status: 🔄 in-progress

PRD row "Resources for the AI, credits for the players" (David, 2026-11-16); analysis note 07 §26.

## What

- Each side has **one stock of resource points** (`dynamic.resources.start`, 500), saved with the campaign.
- **Production**, every beat, in points per hour: a **background** `resources.background_per_hour` (30) whatever happens, plus each factory the side holds, `factory.per_hour` (120) times the share of its buildings standing.
- **Everything the AI puts into play is paid from it**, at the price of its units: a garrison drawn for a captured zone, a reinforcement by the supply network (ticket 13), an assault convoy (counter-attack or rule-based), a supply helicopter, a CAP, a strike, the Hunter, a bomber raid (ticket 17).
- **A sortie keeps a reserve**: a CAP, strike, convoy, helicopter, Hunter or raid is sent only while the stock stays at or above `resources.reserve` (100) after paying, so the AI does not spend on sorties what it needs to rebuild its zones. A network reinforcement and a captured zone's garrison may go down to zero.
- **A captured zone whose garrison the side cannot pay** gets the token garrison (the smallest size class, as an empty reserve did in V1) and pays what it has left: a zone with no garrison would be held for ever.
- **What players buy does not come out of the resources**: a shop purchase or a spawn paid in credits is not charged to them (ticket 14).
- **What survives comes home**: an assault convoy or a paid spawn still in the world when the server stops pays its survivors' price into its side's resources at the next load — the V1 rule that sent a convoy's survivors back to the reserve.
- Off with `resources.enabled: false`: the AI is then free and unlimited, as in V1.

## Prices

One price per unit type (David, 2026-11-16), read from the DCS unit database by what the type is, overridable per type in `resources.prices`:

| what | points | why |
|---|---|---|
| infantry | 1 | a soldier |
| unarmed vehicle | 2 | a lorry |
| APC / IFV | 4 | |
| tank | 6 | a T-72 costs less than an SA-11 battery |
| artillery | 5 | |
| AAA, short-range air defence | 4 | |
| short-range SAM | 8 | |
| medium- or long-range SAM element | 15 | an SA-11 battery of 5 to 7 vehicles ≈ 100 |
| helicopter | 15 | |
| aeroplane | 30 | a MiG-29 costs more than a lorry |
| bomber | 100 | |
| anything else | 5 | |

Default values, chosen so that one factory pays for about one counter-attack and one CAP flight an hour; to be tuned on a server (ticket 10).

## Done when

Lua tests: prices by kind and by override; production with and without factories, by share of standing buildings; each AI spending refused below the reserve and paid above it; a captured zone's token garrison when the stock is short; survivors paid back at load; nothing charged when `enabled` is false; stocks saved and reloaded.
