# 05 — `list_shortcuts` gives no era, and WW2 has no radar or artillery alias

Status: ✅ done
Type: feat (small)
Files: `veaf_libs/data/veaf-units.yaml`, `veaf_mission_mcp/oracle.py` (list_shortcuts), the action's description, the authoring skill

## What happens

Building a WW2 mission through the MCP, an agent must discover by experiment which aliases follow `mission.era`. `-aaa`, `-samSR`, `-samLR`, `-samVLR`, `-armor`, `-transport` do (`generateAirDefenseGroup-<SIDE>-WW2-<n>` groups exist: flak 18/36/37/38/41, KDO Mod 40, Flakscheinwerfer, Bofors, QF 3.7, M45) — but the output says « Random SAM battery », « Random medium range air defense group », and nothing about era. The ones that do **not** follow it and give modern equipment in a WW2 mission:

- `-blue_ewr` (FPS-117 dome), `-ewr` (55G6), `-dogear`: no alias for the units WW2 does have, `FuMG-401` (Freya), `FuSe-65` (Würzburg), `Allies_Director`;
- `-arty` (M-109), `-mlrs`, `-grad`…: the WW2 field guns `LeFH_18-40-105`, `Wespe124`, `Pak40`, `M2A1-105`, `M12_GMC` have no alias;
- `-convoy`, `-hv_convoy_red`, `-attack_convoy_red` use « RU supply convoy » groups.

The Normandy Open Training placed radars and field guns as native groups of literal types.

## What ships

- Each `commands` / `groups` entry of `list_shortcuts` carries `eras` (the eras its output is correct for, or `follows_era: true`); the authoring skill says to read it.
- WW2 aliases for radars and artillery (names to settle with David): `-freya`, `-wurzburg`, `-flak88`, `-lefh`, `-pak40`, `-wespe`.
- `validate` warns when a `#command` / `#veafInterpreter` alias is not correct for `mission.era`.

## Done when

`list_shortcuts` can be filtered by era; the WW2 radars and field guns have aliases; `validate` flags `-sa6` in a WW2 mission.

## Done

`veaf_libs/shortcut_eras.py` reads the era of a shortcut from what it runs, so a new alias cannot be left unlabelled: `follows_era` (the `_spawn` kinds that go through `veafCasMission.generate*`, `convoy` and `_cas`), `ww2`, `post_ww2`, `era_free`, `unknown` (`-jtac`, `-afac`, `-cargo`: not measured, so not claimed). `list_shortcuts` carries it on every unit, group and command, and takes `era` to filter. `validate` warns about a `#command` or `#veafInterpreter` of a `post_ww2` shortcut in a WW2 mission (a warning, not an error: an unknown one is not claimed). Six WW2 aliases with the names the ticket proposed — `-freya`, `-wurzburg`, `-flak88`, `-lefh`, `-pak40`, `-wespe` — German, one battery each; the names are the ticket's, to be confirmed.

Corrections: `-blue_ewr` and `-dogear` are `blue-ewr` and `dogear` in `veaf-units.yaml`; `-convoy` does follow the era (`spawnConvoy` calls the transport and armour generators), while `-hv_convoy_red` and `-attack_convoy_red` do not.

Not verified in DCS: the six aliases resolve to their unit or group (a test holds that), and `country GERMANY` is read like `country USA`, but none has been spawned in game.
