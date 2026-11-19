# 02 — The sitac shows the players, as Foothold's does

Status: 🧑 waiting-human — implemented, waits for the in-game check
Type: feature

## Found

David, 2026-11-19: the sitac does not show the players' positions "comme ça le faisait sous Foothold. J'aimerais bien que ça fasse la même chose que sur Foothold."
Foothold writes a `players` list in its save (side, aircraft type, player name, latitude, longitude, altitude), and `foothold-sitac` draws it. `veafCampaign.sitacTable()` writes no player.

## To do

- VMCT: the `sitac` block gets a `players` list in Foothold's shape — `coalition` (`"blue"`/`"red"`), `unitType`, `playerName`, `latitude`, `longitude`, `altitude` — built from the units of the connected players (`coalition.getPlayers` per side; check whether `net.get_player_list` is reachable from the mission environment before relying on it), at every state write.
- foothold-sitac: the VEAF reader (`veaf_campaign.py`) maps that list onto the model Foothold's players already use, so the map draws them the same way.
- The rhythm: positions are as fresh as the state write (60 s of simulation). Say so on the page if it differs from Foothold's.

## Done when

On the next evening the sitac shows each connected player on the map, as it did under Foothold, with tests on both sides.

## Implemented (2026-11-19)

`veafCampaign.sitacPlayers()` writes `players` from `coalition.getPlayers`, both sides, in Foothold's shape, at every state write (60 s of simulation). `net.get_player_list` was not needed. Tests: `test_veafCampaignSitac.lua`.

## To check in game

The sitac draws each connected player within a minute of his move.
