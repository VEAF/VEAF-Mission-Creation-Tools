# 03 — Measure the F10 menu on a real multiplayer mission

Status: 🧑 waiting-human — waits for the next VMCT release (David, 2026-10-10)

The missions: the three new Open Training missions, `VEAF-Open-Training-Mission-Caucasus-v6`, `-GermanyCW-v6`, `-Syria-v6`.
On dcs.veaf.org each runs under one fixed name in `Saved Games\DCS.missions\` (`VEAF_OpenTraining_Caucasus_ICAO_UGTB.miz`, `VEAF_OpenTraining_GermanyCW_ICAO_ETAR.miz`, `VEAF_OpenTraining_Syria_ICAO_LTAG.miz`), shared by private1, private2, public1 and public2: one file per mission covers the four instances at their next load.
They run 6.26.x scripts today, so they do not park yet; the release brings #1113 and the option together.

Decided with David (2026-10-10):

- the option is set in each `mission.yaml` for the build only, not committed: it is temporary, and the built `.miz` is not tracked;
- each mission is loaded once in single player before upload: no script error in `dcs.log`, `radio menu stats` lines present;
- upload with `D:\dev\_VEAF\server-tools\Update-ServerMission.ps1`, `-WhatIf` first; running missions are left alone;
- nothing permanent on the production server: the network is sampled over SSH on the evenings David names.

## How

1. Update each mission's tools (`veaf-tools-updater.exe`), then build it with `modules.RADIO.menu_stats: true`, plus `logLevel: info` under `RADIO` if the mission's `global_log_level` is `warning` or `error` (the module's level outranks the global one).
2. During the session, sample the server's network output over SSH, every 10 s, into a file — read-only, nothing to start on the server:

   ```powershell
   while ($true) { $s = Get-NetAdapterStatistics; "{0:o};{1};{2}" -f (Get-Date).ToUniversalTime(), $s.SentBytes, $s.ReceivedBytes; Start-Sleep 10 }
   ```

   The timestamps are written in UTC, like `dcs.log`: the machine's clock runs at local time.
3. Copy the instance's `dcs.log` the same evening: it does not survive the next restart.
4. Read the `radio menu stats` lines: how big the menu gets, how often it changes, how many ids get parked by the end; set the output peaks against the menu changes.
5. Ask the players whether the F10 menu lagged or desynchronised.

## Done when

- The figures (live entries, adds and removes per hour, parked total, output around the menu changes) are in the whitepapers' section 8 and in this ticket.
- If parked commands show a network cost, a lot to bound them is written up; otherwise the whitepapers say they do not.
- The option is turned off again on the mission.
