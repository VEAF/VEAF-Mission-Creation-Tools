# DOC-TUTORIAL-NEXT-STEPS — the tutorial stops before the three things a mission maker does next

Status: 🔄 in-progress

Origin: David, 2026-10-06 — "help me write a tutorial on how to install, configure and use VMCT".
[`doc/mission-maker/TUTORIAL.md`](../../doc/mission-maker/TUTORIAL.md) already covers installing and using; this lot completes it rather than adding a page.

## What is missing

| Gap | Where it lives today | Why the tutorial needs it |
|---|---|---|
| Setting the tool's language, and `doctor` | [GUIDE](../../doc/mission-maker/GUIDE.md#global-user-configuration) only | the page quotes French messages; a reader whose Windows is in English sees English ones and does not recognise them |
| Getting security back for the server build | nowhere — step 2 says "put it back before deploying" and never says how | a build profile is the answer, and the GUIDE already documents it |
| Updating the tools | [GUIDE](../../doc/mission-maker/GUIDE.md) only | the `.miz` carries its scripts; nobody tells the reader an update means a rebuild |
| Next steps for a v5 mission, a third-party mission, the AI assistant, the demo mission | absent from the step 10 table | the pages exist; a reader who does not browse the menu never finds them |

## Measured, not recalled

Every new output quoted in the page was produced on 2026-10-06 in a scratch mission folder, with the tools built from this branch (6.28.0) and a throwaway `USERPROFILE`:

- `user-config` on a fresh machine: "Aucun fichier de configuration utilisateur trouvé", then `Langue : fr (source : OS/default)`; after `--set lang=fr` the source becomes the file's path.
- `build --profile TEST` prints `Construction avec le profil : TEST` and writes `veaf.SecurityDisabled = true`; the plain build writes no security line, which leaves security on (`veafSecurity.isSecurityDisabled`). `--profile test` resolves to `TEST`; `--profile TSET` warns `Profil 'TSET' introuvable dans mission.yaml — configuration de base utilisée` and builds with security **on**.
- The updater against the real `published-latest` (6.28.0), with `published/package.json` at 6.28.0, so nothing downloaded: `La version installée 6.28.0 est déjà à jour`. The "newer version" line comes from `updater.newer_available` and was not executed (it would download 65 MB).

## Found on the way

Step 4 announces `Modules VEAF actifs (22)`, CSAR and CTLD included. The build prints **20**, without them: `_normalize_mission_yaml` ([`mission_builder_worker.py:573`](../../src/python/veaf-tools/mission_builder/mission_builder_worker.py)) splits `modules:` into `lua_modules` and `community_scripts` before the report runs, and `summarize_active_modules` only reads the first. True since the line was added (#908, 2026-09-02) — the 22 was never measured. Its promise, "a module that is not listed was not read", is false for every community script, though CTLD and CSAR are in the `.miz`.

Fixed in the tool rather than in the page (David, 2026-10-06): the report now reads `community_scripts` too, and the build prints the tutorial's line as written — 22 modules, CSAR and CTLD included, measured on the scratch folder.

## Tickets

- [01 — Set the tool's language, and `doctor`](tickets/01-step-0-configure.md)
- [02 — The server build, through a profile](tickets/02-server-profile.md)
- [03 — Updating the tools](tickets/03-update.md)
- [04 — The "what next" table](tickets/04-next-table.md)
- [05 — The build names its community scripts](tickets/05-report-community-scripts.md)
