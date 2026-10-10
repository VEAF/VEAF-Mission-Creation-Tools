# 01 — Every aircraft gets its radio presets and the right kneeboard

Status: ✅ done
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

## Measured (2026-10-09)

**The build did not lose them; the mission was given the wrong plan.**
The built `.miz` and the one the server served (fetched over SFTP) are identical on this: 50 blue dynamic-slot templates with a `Radio` table, 209 `linkDynTempl` resolving to them (Batumi's `F-15ESE` → group 497, `F-15E S4+ Template`), 53 kneeboards.
But the channels are those of the mission folder's `src/presets.yaml`, which is the shipped default plan (Magic 282.2, Arco-1 290.5, Beslan, Sochi-Adler…), while the mission placed its AWACS `Overlord 1` on 251 MHz and its tanker Arco on 252 — what `briefing.yaml` announces.
David, the same day: the kneeboards were "ceux de l'OT, par ex. 282.2 pour Magic alors que dans la mission c'était Overlord sur je crois 251"; on the Open Trainings the dynamic slots do get their presets.

So the presets and the kneeboard agree with each other and not with the mission: nothing reconciles `presets.yaml` with the support groups and airfields a mission actually has.
