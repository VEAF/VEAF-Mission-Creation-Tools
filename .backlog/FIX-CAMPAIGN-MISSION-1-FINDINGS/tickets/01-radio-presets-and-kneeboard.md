# 01 — Every aircraft gets its radio presets and the right kneeboard

Status: ⬜ ready
Type: fix

## Found

David, 2026-10-08, during the flight: no radio channels and no correct kneeboard, then "pour les canaux et la planchette c'est pour tout le monde pareil" — every aircraft, every airfield, not one module.
(He first named the A-10C at Kobuleti; its missing waypoints were his own mistake, not a defect.)

The mission folder holds `src/presets.yaml` (45 KB) and a `presets-validation-report.md`, so presets were declared; whether they reached the aircraft is the question.

## To do

- Find where the presets and the kneeboard are lost between the campaign's `template/`, the folder `campaign next` creates, the build, and the `.miz` the server ran (`.dcssb\Kolkhida_20261008.miz.orig` on dcs.veaf.org is the file as uploaded).
  Read the built `.miz` first: a unit's `Radio` table and the `KNEEBOARD` folder say which step dropped them.
- Check the dynamic-slot path too: the blue slots are dynamic (`Batumi_F-15E S4+_75-1`, `Kobuleti_CH-47F_0-1`), and a dynamic slot takes its radios and kneeboard from its template, not from a placed unit.
- Fix it where it is lost, with a test that builds a campaign mission and reads the presets and the kneeboard back from the built file.

## Done when

A mission built by `campaign next` from the *Kolkhida* template has the presets and the kneeboard on every player aircraft, dynamic slots included, read from the built `.miz`.
