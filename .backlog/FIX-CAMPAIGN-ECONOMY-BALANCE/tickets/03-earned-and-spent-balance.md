# 03 — An evening's balance: earned and spent

Status: ⬜ ready
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
