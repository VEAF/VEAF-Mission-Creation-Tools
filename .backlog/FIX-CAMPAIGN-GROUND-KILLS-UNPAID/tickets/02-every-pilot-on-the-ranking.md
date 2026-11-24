# 02 — Every pilot who flew is on the ranking

Status: ✅ done
Type: fix

## To do

- A pilot of the players' side gets his books (`veafCampaignEconomy.pilots[<player>]`, zero everywhere) when he first takes a slot in the campaign, not at his first gain: the sitac's ranking (`sitacStats`) then lists every pilot who flew, with zero points if he earned nothing.
  Hook it where the campaign already sees a player enter a unit (the welcome brief or the CTLD player manager read `S_EVENT_PLAYER_ENTER_UNIT` / `S_EVENT_BIRTH`); a game master slot or a spectator gets none.
- The books stay in the save as today; a pilot of the enemy side (PvP) is left out, as `sitacStats` leaves the team out.
- Tests: a pilot who entered a slot and earned nothing is in `sitacStats` with zero; a gain afterwards adds to the same books.

## Done when

After an evening, the sitac's ranking lists every pilot who took a slot, with his points and kills, zero included; with tests.

## In-game check

After the next evening, the ranking on http://dcs.veaf.org:8080/foothold/map/foothold2_server@Northern%20Syria lists every pilot who flew, compared with the `takeoff` events of `dcs.log`.

## Done (2026-11-22)

- `veafCampaignEconomy.onPlayerEnter`, on `S_EVENT_BIRTH` and `S_EVENT_PLAYER_ENTER_UNIT`: a player's unit of the players' side opens his books (zero everywhere), so `sitacStats` lists him with zero points. An enemy pilot and an AI unit get none; a game master or a spectator has no unit and sends no such event.
- The books are the ones the save already keeps (`pilots`).
- Tests (`TestCampaignEvening`): a pilot who took a slot is on the ranking with `{ Points = 0 }`; a kill afterwards adds to the same books; an enemy pilot and an AI get none.
