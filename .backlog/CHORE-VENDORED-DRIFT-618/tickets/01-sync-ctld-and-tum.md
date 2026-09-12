# 01 — Sync CTLD rc8 and TUM v0.3

Status: ✅ done

## What was done

- `src/scripts/community/CTLD.lua` ← the `CTLD.lua` asset of `published-v2.0.0-rc8`, converted to LF.
- `src/scripts/community/TheUniversalMission.lua` ← `l10n/DEFAULT/Script.lua` extracted from
  `The.Universal.Mission.-.Marianas.miz` of `v0.3.251019`, converted to LF.
- `vendored.yaml`: both pins moved, and the TUM entry rewritten (its `manual_steps` described a
  download that is impossible; the two traps are now stated in the file itself).

## Line endings, because this has cost a release before

Both upstream files ship with CRLF. `.gitattributes` normalises `*.lua` to LF and its own comment
records why: the 6.13.0 release carried 25 000 changed lines, 24 000 of which were one copied CTLD.
Converting on the way in keeps the working tree and the index saying the same thing — CTLD's real
diff is then **410 added / 30 removed**, which can be read.

## Verified

- `poetry run check-vendored`: 0 drifted
- `poetry run pytest test/python/test_vendored_pins_match_the_files.py`: green — it is what would have
  caught a file swapped without its pin
- CTLD's version constant reads `2.0.0-rc8`; TUM's reads `0.1.250722` in every release, so there is
  nothing to assert there (see the PRD)
