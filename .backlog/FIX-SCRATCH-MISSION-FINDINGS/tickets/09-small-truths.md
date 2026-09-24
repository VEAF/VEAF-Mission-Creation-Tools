# 09 — Three small places where the tool says something false, or nothing

Status: ✅ done
Type: fix + doc
Files: `doc/PIPELINE_REFERENCE*.md`, the build's module summary, the build's sound check

1. **`clearsky` is undocumented.** `versions[].clearsky` is read
   (`weather_injector/models/configuration.py:26,60`), caps to FEW / < 15 kt / CAVOK, and is emitted
   by `convert-v5` — absent from the `versions[]` field table.
2. **« QRA (0) »** in the build's module summary, for a mission with one definition using
   `groups_by_enemy_count` (the generated `veaf-config.lua` is right). The count seems to read
   `simple_groups` only.
3. **A missing CSAR sound builds without a word.** `modules.CSAR.settings.radioSound:
   csar-beacon.ogg` (carried over from a v5 mission that shipped the file) while the file is not in
   the mission: the beacon is mute. The build already warns for a missing *required* sound; extend it
   to a sound named in the CSAR / CTLD settings.

## Done when

- Doc row added, summary count right, a test for the sound warning

## Outcome (PR 1)

1. `clearsky` row added to the `versions[]` table (FR/EN).
2. « QRA (0) »: the build normalises `mission.yaml` first, which moves `modules.QRA.definitions` into a
   separate `qra` section; the summary read the moved-from place. Its test fed the raw file. Fixed and
   tested on the normalised dict; bench now reads QRA (1).
3. Sounds named in the CTLD/CSAR settings join the required-sound check.
