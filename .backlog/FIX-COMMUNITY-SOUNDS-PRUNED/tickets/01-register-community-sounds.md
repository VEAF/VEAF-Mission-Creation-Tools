# 01 — Register the sounds so the editor keeps them

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/mission_builder/mission_builder_worker.py`, `test/python/`

## Tasks

- [ ] When CTLD or CSAR is enabled, emit a mission-start action playing **each** injected sound to
      a country **absent from the mission's coalitions**, and add the matching `mapResource` entry.
      That pairing is the whole fix: the trigger alone does nothing, the `mapResource` entry alone
      is what the editor reads.
- [ ] Pick the unused country by **checking the mission**, not by hardcoding 7. A hardcoded id is
      correct until the day someone uses that country and starts hearing beacons at mission start.
- [ ] Reuse `_find_community_sound_resource_keys` — the removal side already knows how to find
      these keys, so creation and removal should agree by construction rather than by coincidence.
- [ ] Symmetry test: build with CTLD on, save through the editor, assert the sounds survive. The
      unit test that merely asserts a trigger exists would have passed all along.

## Watch out

`radiobeep.ogg` was added later (BUILD-COMMUNITY-SOUNDS-002, #505) and is auto-injected for CTLD.
It needs the same treatment — the mapping is the source of truth, not the three names in the
original lot.
