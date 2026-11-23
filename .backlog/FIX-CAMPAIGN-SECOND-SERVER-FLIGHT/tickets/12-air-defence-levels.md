# 12 — The air defence of a zone is too light

Status: 🧑 waiting-human
Type: fix

## Found

David, 2026-11-17: only short-range infrared SAMs, "pas très réaliste"; a base like Aleppo should have SA-15, Tunguska, SA-8, "le genre de SAM qu'on a un peu partout normalement".
A zone's air defence comes from its size class (`DEFAULT_SIZE_CLASSES`, `campaign_manager/models.py`): `airfield` = defence 3 → `generateAirDefenseGroup-RED-3` (Strela-10, Strela-1, Shilka, ZSU-57, S-60); `outpost` = defence 1 (Shilka alone).
SA-8 (Osa) comes at level 4, SA-15 (Tor) and Tunguska at level 5 (`veaf-units.yaml`), with a die of ±1 at the draw (`generateAirDefenseGroup`). An airfield of level 3 also draws a single air defence group (`composeGarrison`: two above level 3).

## To do

- New defaults: reco `airfield` defence 5, `outpost` defence 3; a campaign may still lower them with `size_classes:` (`CAMPAIGN.md`). The modern era only; the cold-war and WW2 variants keep their own tables.
- The Oronte campaign: its `campaign.yaml` follows, and its **red garrisons already recorded in the save are redrawn** — removed from the state so the next load draws them free with the new levels (`veafCampaign.lua`, the load path: a placed, owned zone without a garrison draws one, from no reserve in mission 1). An operation on the live server: server empty, the state's diff shown to David first, his go.
- The tests of the size classes and the doc (`CAMPAIGN.md` and `.en.md`) follow.

## Done when

A red airfield of the next evening has an SA-8 or better and a Tunguska or Tor, and an outpost an SA-9/13 or better.

## Done

- `DEFAULT_SIZE_CLASSES` (`campaign_manager/models.py`): `airfield` defence 5, `outpost` defence 3, with the reason in the comment.
  Defence 5 draws **two** air defence groups (`composeGarrison`: two above level 3), each of level 4 or 5 after the die (`generateAirDefenseGroup-RED-4`: SA-8, Strela-10, Shilka…; `-RED-5`: Tor, SA-8, Tunguska, Strela-10…): both at level 4 one draw in 25.
  Defence 3 draws one group of level 2 to 4 (Strela-1, Strela-10, sometimes SA-8). The era tables are untouched: a cold-war or WW2 campaign gets its own table for the same level.
- Tests and `CAMPAIGN.md` / `.en.md` (the size-class table; the unit counts are marked not measured yet).
- The Oronte `campaign.yaml` declares no `size_classes:`: it follows the new defaults with no change; the next build of its mission carries them.

## Left: redraw Oronte's red garrisons (live server, David's go, server empty)

The garrisons already recorded in the save keep their old air defence until they are drawn again.
A placed, owned zone **without** a `garrison` in the save draws one at the next load (`veafCampaign.lua`, the load loop: "a zone without a garrison"), free in mission 1 (Oronte stays mission 1).

1. Stop the mission, server empty (`bot stop` on the Campagne instance, foothold2).
2. Fetch by SFTP `C:/Users/veaf/Saved Games/foothold2_server/Missions/Saves/Northern Syria/persistent.state` (the folder is the campaign's `name`), and its `persistent.state.tmp` if there is one.
3. On the local copy, remove the `garrison` key of every zone whose `owner` is `"red"`, and nothing else — this script prints the zones touched and writes `persistent.state.new` beside it:

   ```powershell
   poetry run python -c "import sys,luadata,pathlib; p=pathlib.Path(sys.argv[1]); t=luadata.unserialize(p.read_text(encoding='utf-8').removeprefix('return'), encoding='utf-8'); red=[n for n,z in t['zones'].items() if z.get('owner')=='red' and z.pop('garrison',None) is not None]; print('redrawn:', ', '.join(sorted(red))); p.with_name(p.name+'.new').write_text('return '+luadata.serialize(t, encoding='utf-8', indent='  ')+chr(10), encoding='utf-8')" "C:\Temp\persistent.state"
   ```

4. Show David the diff before anything goes back: `git diff --no-index --stat "C:\Temp\persistent.state" "C:\Temp\persistent.state.new"` and the list printed above (the red zones; Menagh and Afrin are blue and keep theirs). Credits, stocks, convoys and the other zones must not move: the parse–write round trip only re-indents.
5. On David's go: upload `persistent.state.new` as `persistent.state`, **delete** `persistent.state.tmp` (the load falls back on it when the state is unreadable), `bot start`.
6. Check in `dcs.log`: one "garrison drawn" per red zone at the load, and no `the campaign's save could not be read`.

The garrisons redrawn this way also leave the roofs (ticket 07).

## In-game check

A red airfield (Aleppo, Kuweires) has an SA-8 or better and a Tunguska or Tor; an outpost an SA-9/13 or better (F10 map with the game master slot, or Tacview).
