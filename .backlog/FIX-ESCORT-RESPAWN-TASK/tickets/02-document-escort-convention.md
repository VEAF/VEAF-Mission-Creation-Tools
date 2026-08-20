# 02 — Document the escort convention on the ASSETS page

Status: ✅ done 2026-08-20 — ASSETS page in both languages, plus the API reference entry for `veafAssets.respawn`
Type: docs
Files: `doc/mission-maker/scripts/veafAssets.md` + `.en.md`

## What is missing today

Nothing tells a mission maker that an asset's escort must be named `<asset> escort`. The convention
is implicit in `veafMove.teleportEscort`, and a mission maker cannot read Lua to find it. Today the
ASSETS page documents `linked` as *"name of a linked asset (e.g. a carrier linked to its escort)"*,
which reads as if `linked` were what makes an escort an escort. It is not.

## What to write

- The escort of an asset is the group named `<asset name> escort`, and that name is what lets the
  framework repair the escort's task when the asset is respawned or teleported.
- `linked` is a separate thing: it lists groups to **respawn along with** the asset. An escort may or
  may not be in it — the two mechanisms are independent, and saying so is the point of this ticket.
- One sentence on the symptom, because it is how a mission maker will arrive on this page: an escort
  that flies its route and lands after about ten minutes was an escort whose task DCS invalidated.

Both languages, and the anchor convention applies if the section is linked from elsewhere.

## Done when

`poetry run docs-check` passes and both pages say the same thing.
