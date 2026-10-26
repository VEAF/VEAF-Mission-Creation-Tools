# 03 — The window opens API logs and their older files

Status: ⬜ ready

- `Fichier › Ouvrir un journal distant…` lists the API servers beside the SSH ones, with their discovered instances and bot log; a tab is `veaf-api:private1`, reopened at the next launch as the SSH tabs are (`internal/logview` session order).
- `Fichier › Ouvrir un ancien journal…` on an API tab lists `/instance/logs` (or `/node/logs`) with sizes and dates, and opens the chosen file read-only: `file=<name>&tail=false`, then the cursor, chunk by chunk, with the progress the window already shows for a big local file.
- The status bar says: authentication refused (with ticket 02's hint), no log yet, instance or file unknown, log on another node (501), server unreachable, and after a `gap` "the log restarted, some lines were lost".

## Done when

- `internal/logview` tests for the session order and the tab names of API tabs.
- `--smoke` still passes; an API tab cannot be tested there, so the window part is checked by hand against a local bot or a fake API, and the PR says how.
