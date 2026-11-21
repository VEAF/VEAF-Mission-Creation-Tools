# 02 — Every pilot who flew is on the ranking

Status: ⬜ ready
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
