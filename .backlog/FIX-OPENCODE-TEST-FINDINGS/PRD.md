# FIX-OPENCODE-TEST-FINDINGS — what an AI with nothing but veaf-tools met, end to end

Status: 🔄 in-progress

Origin: David's end-to-end test on 6.31.1, 2026-10-20 — OpenCode with MiniMax M3.1 Flash (free), on a Windows sandbox set up like any user's, "crée une mission DCS".
David stopped it after 161 minutes: 312 turns, 378 tool calls of which 162 in a shell, 188 million cache-read tokens (one tool call per turn, the whole context sent back each time), a compaction at 158 minutes, and a mission still not finished.
The export is the source of every figure below (`C:\tmp\cr-ation-d-une-mission-dcs.json`, on DAVID-BUREAU).

Decision (David, 2026-10-20): everything in one lot, one PR, released as 6.31.2.
It absorbs `FEAT-INSPECT-BUILT-MISSION`, opened the same day and not started, now tickets 07 and 08.

## Findings

| # | Finding | Measured |
|---|---|---|
| 1 | The MCP self-update replaces `veaf-tools.exe` under running servers; their next first-time import fails | **reproduced** |
| 2 | `edit_mission_file` cannot match a multi-line passage in a CRLF file, and the scaffold the exe writes is CRLF | **reproduced** |
| 3 | Before a mission folder exists, the AI digs the exe's extracted data (`_MEI…\veaf_libs\data`) for facts no action serves | seen in the export |
| 4 | Build: "injected presets into 4 aircraft" of 59 groups, a report announced "0 issues found" that is then absent, channel 1 of the A-10C template at 122.1 (Incirlik's VHF) | to investigate |
| 5 | The FARP gets no dynamic slot ("0 ships/FARPs", then "Ship/FARP '1' not found in the mission (farps)") | to investigate — may be the AI's own hand edits of `src/mission/warehouses` |
| 6 | A few reads weigh most of the context | seen in the export |
| 7 | No action reports what a built `.miz` holds, and the guide asks to check it | see tickets 07–08 |

### 1 — the self-update breaks running servers (reproduced 2026-10-20)

6.31.1 was published at 18:30, during the session.
A server's self-update ran the updater, which renamed the running `veaf-tools.exe` aside and moved 6.31.1 in — while four `veaf-tools.exe mcp` processes were running (one per AI session).
A PyInstaller onefile executable reads its Python modules from its own file, by path, the first time each is imported; after the swap it reads the new file at the old file's offsets.

Measured on DAVID-BUREAU: a 6.31.0 server, one action run, the exe swapped for 6.31.1 on disk, then:

| Action after the swap | Result |
|---|---|
| `describe_mission` (already imported) | ok |
| `set_airbase_coalition` | `error: Error -3 while decompressing data: incorrect header check` |
| `validate_mission` | `error: Error -3 while decompressing data: unknown compression method` |

The two messages of the sandbox, in the same order.
From there the AI spent about 80 minutes hunting a corrupt file: it edited `warehouses` by hand, broke the build (`Unserialize luadata failed`), and truncated `presets.yaml` with PowerShell.
`build_mission_briefing` failed the same way to the end, even on a fresh folder.

### 2 — CRLF

The scaffold written by the 6.31.1 exe is CRLF (`read_mission_file` returns `\r\n`; measured on DAVID-BUREAU).
A multi-line `search` sent with `\n` is "passage not found"; the AI then rewrote the line ends itself (`const NL="\r\n"`), and for `presets.yaml` fell back to PowerShell, which truncated the file.

### 3 — what the AI looked for outside the actions

Before `scaffold_mission` (phase 1 of the objective prompt is read-only), and after:

- DCS country ids (Turkey, Syria, Russia, USA) — read `dcs-countries.yaml` in `_MEI…`;
- the number of parking places per Syria airfield — read `parking\Syria.json`;
- the airfields' ATC frequencies for the frequency plan — read `airfield-frequencies.yaml` (`describe_airfield_channels` needs a mission and returns nothing until bases are set);
- whether a type can be placed as a static (a parked Su-24) — grepped `dcsUnits.yaml`;
- the shipped dynamic-slot templates (types, frequencies) — read `published\src\defaults\…\dynamic-slot-templates.yaml`;
- lat/lon ↔ x/y with no mission folder — it fitted its own linear model on `list_airfields` (5 km residual);
- the `combat_zones` keys (`chained_zones`) — grepped `veaf-scripts.lua`.

### 6 — the heaviest reads

| Read | Calls | Characters |
|---|---|---|
| `describe_mission_prompt` | 3 | 80k |
| `describe_action` (often batched, 6–10 actions at once) | 11 | 72k |
| `describe_known_limitations` (three areas in full, 46k in one call) | 3 | 65k |
| `list_airfields` | 3 | 41k |
| `list_unit_types` | 9 | 39k |
| `read_mission_file` | 32 | 34k |

## Tickets

- [01 — The self-update never replaces a running exe](tickets/01-self-update-stages.md)
- [02 — `edit_mission_file` matches across CRLF](tickets/02-edit-crlf.md)
- [03 — The reference data an AI needs before a mission folder exists](tickets/03-reference-data-without-folder.md)
- [04 — Presets: 4 aircraft injected, a report that is not there](tickets/04-presets-injection-report.md)
- [05 — The FARP's dynamic slots](tickets/05-farp-dynamic-slots.md)
- [06 — Lighter reads](tickets/06-lighter-reads.md)
- [07 — `inspect_built_mission`](tickets/07-inspect-built-mission.md)
- [08 — The guide checks through the action, never through a shell](tickets/08-guide-no-shell-parsing.md)
