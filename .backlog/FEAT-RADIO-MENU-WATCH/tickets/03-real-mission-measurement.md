# 03 — Measure the F10 menu on a real multiplayer mission

Status: ⬜ ready — needs a release with ticket 01 and a mission flown on dcs.veaf.org

## How

1. Build the evening's mission (an OT or another real one) with `modules.RADIO.menu_stats: true`, plus `logLevel: info` under `RADIO` if the mission's `global_log_level` is `warning` or `error` (the module's level outranks the global one).
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
