# 03 — Step 8 gets a block it can actually uncomment

Status: ✅ done

Type: docs

## The problem

Step 8 says *"décommentez le bloc `COMBATZONE`"*. There is no such block. Step 1 selects
`--template minimal`, and COMBATZONE belongs to `standard`/`full`
([`mission_template.py:205`](../../../src/python/veaf-tools/veaf_libs/mission_template.py)); the
generator's own header states that *"modules outside the set are omitted"*.

Paluche's words: *"Je ne pouvais dès lors pas la décommenter. J'ai alors copié le bloc Combatzone
présent dans le tuto et je ne savais pas trop à quel endroit l'insérer dans le mission.yaml. Un
grand moment de solitude !"*

He also had no confirmation at build time: *"je n'ai vu aucun message concernant la création de la
Combatzone"*. That is ticket 04; this ticket owes the step a "how you know" that is true today.

## The decision (David, 2026-09-02)

Step 1 switches to `--template standard`, so that "uncomment" describes reality. Measured on
2026-09-02 in a throwaway folder:

- `standard` writes the `COMBATZONE` block commented, under a `# ── Combat ──` heading
- `validate` reports **0 errors, 3 warnings** — the same three, word for word, as `minimal`, so
  step 3 stands unchanged
- the `pipeline:` block is identical in both files, so the build output does not change

Three consequences to carry through:

1. The shipped block says `training: false`; the step wants `true`. Say so.
2. `standard` also turns on STTS, CSAR and CTLD, so the F10 menu at step 6 holds more than the page
   promises. **STTS with no SRS installed is unverified** — no DCS on this machine; flag it rather
   than claim it is harmless.
3. Step 2 quotes the `modules:` block; the `standard` one is longer and the excerpt must be
   refreshed.

Uncommenting must be explained as *removing the `#` without touching the spaces* — the block is
written `#   COMBATZONE:` and lands at two spaces of indent.

## Step 9 rides along

Step 9 tells the reader to give an airfield to the blue coalition. Adding a blue client slot at
step 5 already does it, and the shipped `src/warehouses.yaml` enables dynamic slots on every
coalition-owned airbase — its own header says so. Paluche: *"Je n'ai donc rien eu à faire."* The
step becomes a check, not an action.

## Definition of done

- [x] Step 1 uses `--template standard`, and says what the tier buys
- [x] Step 2's `modules:` excerpt matches what `standard` writes
- [x] Step 8 uncomments a block that exists, states the `#`-only edit, and flips `training`
- [x] Step 8 has a "how you know" that holds before DCS is launched
- [x] Step 6 does not promise a menu smaller than the one `standard` produces
- [x] Step 9 reads as a verification
- [x] Both languages
- [x] `poetry run docs-check` passes
