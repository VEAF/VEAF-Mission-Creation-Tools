# 01 — Read every module's preset counts

Status: ✅ done

## Done when

- A script reads the `panelRadio` table of each aircraft module of a DCS install and outputs, per type and per radio, the channel count and the source file (PRD D2); it is tested on fixtures copied from real module files (the OH-58D's must give 20, 20, 21, 21).
- Run on this machine's install (`C:\jeux\DCS World`), its result is checked in, with the DCS version it was read from.
- The types without a readable table are listed in the PRD's Outcome.
