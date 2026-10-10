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

## Progress

- **Caucasus, 2026-10-10**: built with 6.29.0 and `menu_stats: true`, loaded in single player as a blue game master — no script error, three `radio menu stats` lines (271 live entries at start, 231 for everyone and 40 per coalition; 434 once a group was taken, 25 ids parked). Uploaded over `DCS.missions\VEAF_OpenTraining_Caucasus_ICAO_UGTB.miz`, SHA-256 checked; it runs at the next `/mission load`. The instrumented `.miz` is kept out of the mission's repository, in its `.veaf-backups/instrumente-menu-stats-20261010/`. The recompilation's other findings are `FIX-OPEN-TRAINING-CAUCASUS-FINDINGS`.
- **GermanyCW, 2026-10-10**: built with 6.29.0 and `menu_stats: true`, loaded in multiplayer by David on an A-10C II dynamic slot at Büchel — no script error, two `radio menu stats` lines (208 live entries at start, 169 for everyone and 39 per coalition; 346 once the group was taken, 138 of them for that group; no id parked). The 6.29 MISSIONS-menu leak seen on Caucasus does not reach it: its six CAP missions are declared in `veaf-config.lua` before `veafCombatMission.initialize()`, and DCS Fiddle shows no command at the VEAF root. The instrumented `.miz` is kept out of the mission's repository, in its `.veaf-backups/instrumente-menu-stats-20261010/`. Uploaded on 2026-10-11 over `DCS.missions\VEAF_OpenTraining_GermanyCW_ICAO_ETAR.miz` (private1 and private2 had to leave it first: DCS locks the file), SHA-256 checked; it runs at the next `/mission load`.
- **Syria, 2026-10-10**: built with 6.29.0 and `menu_stats: true`, loaded in multiplayer by David (host, one group taken) — no script error, no CTLD « réglage(s) absent(s) » notice, two `radio menu stats` lines (478 live entries at start, 403 for everyone and 75 per coalition; 626 once the group was taken, 148 of them for that group; no id parked). Its CAP and combat missions are all declared in `mission.yaml`, so the 6.29 MISSIONS-menu leak does not reach it: DCS Fiddle shows no command at the VEAF root and the ten missions under MISSIONS. The instrumented `.miz` is kept out of the mission's repository, in its `.veaf-backups/instrumente-menu-stats-20261010/`. Not uploaded yet. The recompilation's other finding is `FIX-OPEN-TRAINING-CAUCASUS-FINDINGS` ticket 05.

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
