# 01 — Rewards aligned on Foothold's

Status: ⬜ ready
Type: fix

## Decided

David, 2026-11-20 (a): the players' rewards take Foothold's values, already proven on its servers.

## To do

- `economy` defaults: a SAM destroyed 30 (a unit with `SAM SR`, `SAM TR` or `IR Guided SAM`, as Foothold reads it, or the attribute our ranking already uses for `SAM`), an aeroplane or a helicopter 50, a building 100 — any building of an enemy zone (a factory's, a depot's) destroyed by a player, not only by the sappers —, a pilot rescued 200 (a CSAR pick-up delivered to a friendly zone; credited to the rescuing pilot).
- Each a setting next to `kill_ground` and `kill_air`, so a campaign tunes it; the landing share (`landing_share`) applies to them as to the other kills.
- The player document's and `PERSISTENT_CAMPAIGN.md`'s reward table follow.
- Tests (TDD) per reward.

## Done when

A SAM, an aircraft, a building and a rescue each pay their new reward in the tests, and the in-game check is written.
