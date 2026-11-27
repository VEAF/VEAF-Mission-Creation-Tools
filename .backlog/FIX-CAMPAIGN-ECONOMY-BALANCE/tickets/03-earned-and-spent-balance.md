# 03 — An evening's balance: earned and spent

Status: ✅ done
Type: feature

## Decided

David, 2026-11-20 (c): measure what the players earn and spend, then tune the prices after two evenings.

## To do

- Extend the session summary (`veafCampaignEconomy.summarizeSession`, its `CREDITS SUMMARY` lines) with what was **spent**: per shop item bought (count and credits), per spawn paid in credits, and the balance at the start and the end of the session.
- The same for the enemy's resources: earned (production, refunds) and spent by kind (flights, helicopters, convoys, reinforcements at spawn price), so the debrief reads both sides from the log instead of rebuilding them from `CAMPAIGN STATUS` lines.
- One block of `ECONOMY SUMMARY` lines at the end of a session (mission end, last player leaving), readable after the fact.
- Tests (TDD).

## Done when

After an evening, the log gives each side's earned and spent by kind in one block, with tests.

## Done (2026-11-20)

- `veafCampaignEconomy.ledger`: the session's books, opened by the economy's beat the first time a player sits in a slot (`openLedger`, at the balances of then), closed by the session's summary. Accounts: `credits` (the players' side), and each side's resources when the logistics count them.
- `veafCampaignEconomy.book(account, direction, kind, amount)` writes a flow:
  - credits earned: every gain by its kind — the kill's reward setting (`kill_ground`, `kill_sam`, `kill_air`, `kill_building`; a kill's held share is written under its kind at landing, the kill counted once), else its reason (`capture`, `delivery`, `task`, `rescue`, `demolition`, `warehouse`…);
  - credits spent: `shop <item>`, `shop escort`, `upgrade <upgrade>`, `shop assault` (the assault order, `charge`), `spawn` (a paid VEAF spawn);
  - resources earned: `production`, `refund` (a convoy retired, a flight grounded, a delivery's unspent points);
  - resources spent: `flight` (CAP, strikes, the Hunter), `helicopter` (supply helicopters), `raid` (the bombers' package), `convoy`, `garrison` (a captured zone's), `reinforcement` (a supply delivery, the units a delivery brings back, at their spawn price), `spawn`.
  `veafCampaign.pay`, `veafCampaignLogistics.pay` and `veafCampaignOps.paidSortie` take the kind as a last, optional argument; `veafCampaignLogistics.credit` books only when given one.
- `summarizeSession` writes, after the `CREDITS SUMMARY` lines, one block of `ECONOMY SUMMARY` lines: the session's minutes; per account, the balance at the start and at the end, then earned and spent by kind, largest first, each with its count. Said at the mission's end and when the last player leaves, as before; no block when no player sat in a slot.
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: the debrief's log section, with an example block.
- Tests: `TestCampaignShop` (a session's kill, landing and purchases; nobody played; the mission's end) and `TestCampaignEconomySummary` (both sides' resources, a paid spawn, flights and helicopters by kind).

## In-game check

1. Fly an evening on the Campagne server, then leave the slot (or end the mission).
2. `dcs.log`: one block of `ECONOMY SUMMARY` lines after the `CREDITS SUMMARY` ones — the minutes played; `blue credits`, `red resources`, `blue resources`, each with its start and end balance, earned and spent by kind.
3. The start and end balances match the `CAMPAIGN STATUS` lines around the session; for each account, earned minus spent equals end minus start (a held share lost with its pilot was never earned).
