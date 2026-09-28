# 04 — No action makes a unit transmit a sound, or embeds the sound

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (`edit_route` task set or a new action, the
mission folder writer), tests, AI catalogue doc

## Origin

The Open Training prompt (§4.6) proposes a non-combat helicopter zone: "des balises radio sur
l'itinéraire (sons joués en boucle, fréquences FM données au briefing) et un signal de détresse sur
le lieu … Les sons doivent exister dans la mission." GermanyCW-v6, 2026-09-28.

## Measured

- The v5 "Mountain Hike" does it with a ground unit whose first route point carries
  `SetFrequency` (31 / 32 / 33 / 34 MHz FM) and `TransmitMessage` (`file` = a `ResKey`, `loop =
  true`, a `DictKey` subtitle). It transmits from its position, so a helicopter can home on it with
  its direction finder, and only while the combat zone that owns it is active.
- `edit_route` has `set_frequency` but no `transmit_message`.
- Nothing puts a sound file in `src/mission/l10n/DEFAULT/` and declares it in `mapResource`
  (`add_startup_script_trigger` touches `mapResource` for scripts only).

Worked around by copying the v5 groups and their four `.ogg` files, and writing `mapResource` and
`dictionary` by hand.

## Done when

- `edit_route` takes `transmit_message` (sound, loop, subtitle), validated against the sounds the
  mission holds.
- An action adds a sound to the mission folder (copied into `l10n/DEFAULT`, declared in
  `mapResource`) and returns the key to use.
- Tested; the prompt's beacon zone can be built without a script.
