# 03 — Training ranges out of the forests

Status: ⬜ ready

Files: the training combat zones of the Open Training repositories, starting with Syria.

## What happened

David, 2026-11-15: the northern helicopter range of the Syria Open Training, near YF69 (`H1/H2/H3 Hélico Ceyhan`, 8 km east of the Ceyhan FARP), stands in the middle of a forest; its units spawn hidden in the trees, which makes no sense for a training range.
It is the same defect as the Akamas range (moved 2026-11-12): on Syria the DCS probe behind `clear-ground-check` does not see some forests (`disposition-blind-to-akamas-forest` in `known-limitations.yaml`), so a clean check proved nothing there.

## What to do

- Move the three Ceyhan helicopter tiers to open ground, keeping the distance from the FARP short, and check the new spot by eye in game (F10 view or smoke on each unit), as was done for Akamas.
- Then go through every other training zone of the Syria Open Training the same way: the probe being blind, only a look in game tells.
- On the other theatres, run `clear-ground-check` on every training zone; any zone whose check is doubtful, or that a player reports, gets the same look in game.
- Widen the known limitation: it is not only the Akamas forest, and the Ceyhan range is a second measured case.

## Done when

- No unit of an Open Training training zone spawns in a wood, checked by eye on Syria and by `clear-ground-check` elsewhere.
- `known-limitations.yaml` names Ceyhan as a second case and `docs/agents/dcs-runtime-traps.md` is regenerated.
