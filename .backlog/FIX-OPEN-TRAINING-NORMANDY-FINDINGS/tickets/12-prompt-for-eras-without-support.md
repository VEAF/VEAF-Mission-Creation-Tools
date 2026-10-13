# 12 — The Open Training prompt assumes a modern theatre; WW2 needs its own rules

Status: ✅ done
Type: doc
Files: `.prompts/new-open-training-mission.fr.md`, `.prompts/new-open-training-mission.en.md`

## What happens

Building the Normandy 1944 mission from the prompt, most sections had to be re-read against the era, and each reading was a decision the prompt did not make:

- **4.3 support**: « au moins 2 ravitailleurs, au moins 1 AWACS ». 1944 has none, and DCS has no WW2 tanker or AWACS. The Normandy mission places none (and says so in the briefing) rather than an E-3 or a KC-135.
- **4.1 / 4.11 FARP, CTLD, CSAR, `ctld-config.yaml`, drones laser, carriers (« toujours deux porte-avions »)**: no WW2 helicopter, no WW2 carrier in the module list. The modules are switched off (`CTLD: false`, `CSAR: false`, `CARRIER: false`, `SKYNET: false`), not left on for nobody.
- **4.5 / 4.6 air defence and training families**: « SAM courte, moyenne, longue portée », « SEAD », « hélicoptères ». The WW2 equivalents are flak (20, 37, 88 mm: `-aaa`, `-samSR`, `-samLR`, `-samVLR` all follow `mission.era`), the SEAD family becomes antiflak, the helicopter family becomes close air support; the 3 × 3 shape and `includes:` are unchanged. Skynet and its EWR have no meaning; Freya/Würzburg radars are native groups (ticket 05).
- **4.8 QRA, 4.9 CAP**: « emport (pylons, payload, loadout_from) » — gun-only fighters have none to give (tickets 01, 02).
- **4.12, 4.13**: scenarios work (Ju 88 raid, B-17G escort, recce intercept); the F10 drawings and OSM maps work unchanged.

## What ships

A section « Époques sans ravitailleur, sans hélicoptère ou sans SAM » (and the English twin) that says, for WW2 (and for Cold War where it differs): what to leave out, what takes its place, which modules to disable, how to write the briefing about it. Also in §1: ask the era **before** the template, since it changes the template's answer (`full` is for a modern theatre).

Add to §0.3 (« Retours pour VMCT »): the DCS session the build needs — a terrain sweep and a parking capture are two commands run **together**, with `dcs-serve` started once.

## Done when

A WW2 map built from the prompt needs no unwritten decision about tankers, helicopters or SAMs.

## Done

Section 4.14 « Époques sans ravitailleur, sans hélicoptère ou sans SAM » in both prompts, as a table (what the prompt asks, what WW2 has, what to do) and the rule for `post_ww2` aliases; § 0.3 says the terrain sweep and the parking capture run together with one `dcs-serve`; § 0.2 says to read the short listing of the known limitations first. Correction: the era was already asked **before** the template (questions 2 and 3); what was missing was saying why, and what the template becomes in WW2 — added.
