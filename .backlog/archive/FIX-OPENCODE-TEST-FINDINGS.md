# FIX-OPENCODE-TEST-FINDINGS — what an AI with nothing but veaf-tools met, end to end

Status: ✅ done · archived 2026-11-24

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

- [01 — The self-update never replaces a running exe](FIX-OPENCODE-TEST-FINDINGS.md)
- [02 — `edit_mission_file` matches across CRLF](FIX-OPENCODE-TEST-FINDINGS.md)
- [03 — The reference data an AI needs before a mission folder exists](FIX-OPENCODE-TEST-FINDINGS.md)
- [04 — Presets: 4 aircraft injected, a report that is not there](FIX-OPENCODE-TEST-FINDINGS.md)
- [05 — The FARP's dynamic slots](FIX-OPENCODE-TEST-FINDINGS.md)
- [06 — Lighter reads](FIX-OPENCODE-TEST-FINDINGS.md)
- [07 — `inspect_built_mission`](FIX-OPENCODE-TEST-FINDINGS.md)
- [08 — The guide checks through the action, never through a shell](FIX-OPENCODE-TEST-FINDINGS.md)

## Tickets, in full

## 01 — The self-update never replaces a running exe

Status: ✅ done

Today `start_update_if_due` (in `veaf_mission_mcp/self_update.py`) launches the updater, whose `_install_beside_running_exe` renames the running exe aside and moves the new one in — under the server that launched it and every other server running.

Instead:
- the server downloads the new exe beside the installed one (staged, not installed);
- the swap happens at a server start, before anything else is imported, and only when no other `veaf-tools.exe` process runs: the starting server renames itself aside, moves the staged exe in, and runs the new exe `mcp` as its child on the same standard input and output, exiting with its code;
- otherwise the staged exe waits for a later start; the running servers keep working.

The updater run by a user (`veaf-tools-updater.exe`) keeps its current behaviour, but warns when a `veaf-tools.exe` is running.

Done when:
- a test swaps the exe under a running server in the CI-built executable, or the swap logic is tested with the process list and the file moves injected;
- the scenario of the measurement (four servers, an update published mid-session) leaves every running server answering;
- `known-limitations.yaml` records the PyInstaller behaviour (`kind: tool`, fixed in 6.31.2), the CHANGELOG and the install page say an update lands at the next start of the AI.

Note: 6.31.2 itself reaches running 6.31.0/6.31.1 servers through the old mechanism, once.

### Done (2026-10-20)

- `veaf_libs/staged_update.py`: `take_staged_update` puts `veaf-tools.exe.staged` in place and runs it as a child on the same standard streams, only when `running_copies` finds no other process running from the file or from a copy set aside (Windows through `EnumProcesses` / `QueryFullProcessImageNameW`, Linux through `/proc`; any other platform waits).
  The child gets `PYINSTALLER_RESET_ENVIRONMENT=1`: same path as its parent, it would otherwise take the parent's unpacked folder for its own.
  Called from `veaf-tools.py` for `mcp` only, before `main()`; once swapped the process imports nothing more and exits with the child's code (`os._exit`).
- The server's self-update runs the updater with `--stage` (hidden option): the new `veaf-tools.exe` goes to `veaf-tools.exe.staged`; the updater replaces itself as before.
- A run by hand warns when a `veaf-tools.exe` is running, and puts a staged version in place (`published/` already carries its version, so the version check alone would never install it).
- Tests: the swap logic with the process list and the launch injected (`test_staged_update.py`), the real process table on a copied system program, the updater's stage mode (Windows and Unix) and the run by hand.
- Verified on a locally built 6.31.2 (`stage_test.py`, derived from `swap_test.py`): four servers running, the built updater run with `--stage` → exe unchanged, `veaf-tools.exe.staged` written, and all four answered `set_airbase_coalition`, `validate_mission` and `describe_known_limitations` (first-time imports); a fifth server started among them did not swap; the four stopped, a lone start swapped and answered as 6.31.1, the staged file gone, the old exe set aside.
- `known-limitations.yaml`: `self-update-broke-running-servers` (`kind: tool`, `fixed_in: 6.31.2`); install page (both languages) and `TOOLS_REFERENCE` say an update lands at the next start of an assistant.

## 02 — `edit_mission_file` matches across CRLF

Status: ✅ done

`read_mission_file` returns a CRLF file's lines with `\r\n`; an AI copies the passage back with `\n` (or its client normalises it), and a multi-line `search` is "passage not found".

`edit_mission_file` compares `search` and the file with line ends normalised, and writes `replace` with the file's own line end.
`read_mission_file` returns `\n` line ends, whatever the file uses, and says so in its description.

Also find why the scaffold written by the frozen exe is CRLF (the `published` defaults, checked out on the Windows CI runner?) and decide whether it should be LF like the repository.

Done when: tests edit a CRLF and an LF file with a multi-line passage and keep each file's line ends; the scaffold question is answered in the PR.

### Done (2026-10-20)

- `read_mission_file` returns `\n` line ends; `edit_mission_file` compares `search` and the file normalised and writes the file's own line end (CRLF when it has any).
- Why the scaffold was CRLF: not the `published` defaults — those are LF in 6.31.1, measured — but `prepare`, which wrote `mission.yaml` (the template's), `ctld-config.yaml` and the skeleton catalogues with `write_text` in text mode, CRLF on Windows.
  Decided: LF, like the repository and the rest of the scaffold (`newline="\n"`); a test fails when any scaffolded YAML holds a CRLF, and failed before the fix.

## 03 — The reference data an AI needs before a mission folder exists

Status: ✅ done

The export lists what the AI read from the exe's own files instead of an action (PRD, finding 3).
For each, first check whether an action already answers it and the guide or the prompt fails to point to it; add an action only where none does:

- DCS country ids by name;
- parking capacity per airfield of a theatre;
- the ATC frequencies of a theatre's airfields, with no mission;
- whether a type can be placed as a static;
- the shipped dynamic-slot templates (type, frequency);
- lat/lon ↔ x/y for a theatre with no mission folder (`resolve_coordinates`, `geocode` and `terrain_elevation` took a `mission_path`);
- the `combat_zones` keys of `mission.yaml`.

Done when: each item is answered by an action an AI finds from the guide, tested; the prompts' phase 1 (read-only, before the scaffold) can be done without a folder.

### Done (2026-10-20)

| Item | Answered by |
|---|---|
| DCS country ids by name | new `list_countries` (`name_contains`) |
| Parking capacity per airfield | `list_airfields` `details: true` → `parking.planes` / `parking.helicopters` |
| ATC frequencies with no mission | `list_airfields` `details: true` → `atc` (`uhf`, `vhf`, `fm`, `tacan`) |
| A type as a static | already possible: `add_group` `category: static` takes any type of the unit database; its schema now says so |
| Shipped dynamic-slot templates | `read_mission_file` without `mission_path` reads the shipped scaffold |
| lat/lon ↔ x/y with no mission | `resolve_coordinates` and `geocode` take `theatre` (`list_airfields`, `terrain_elevation` already did) |
| `combat_zones` keys | `create_combat_zone`'s `combat_zone` schema lists them; a test checks each is read by the generator |

The objective prompt's phase 1 named the data files (`veaf_libs/data/parking/<theatre>.json`, `freq_alias.py`) and said `geocode` took no theatre: rewritten in both languages to the actions.

## 04 — Presets: 4 aircraft injected, a report that is not there

Status: ✅ done

On the sandbox mission (5 dynamic-slot templates pulled: A-10C II, F-15C, F-16CM, AH-64D, UH-1H; `set_airfield_channels` for Incirlik and Hatay):
- every build said "injected presets into 4 aircraft" for 59 aircraft groups;
- "Validation report written to …\presets-validation-report.md (0 issues found)", and the file was then empty, then absent;
- in the built `.miz`, the A-10C II template's frequency was 122.1 (Incirlik's VHF channel) and the AH-64D's 122.1.

Investigate before fixing — the AI had edited `presets.yaml` by hand (truncated once, restored), so part of this may be its doing.
Rebuild the same mission from a clean scaffold through the actions only, and measure each of the three points.
A real defect is fixed here; a non-defect is written down in this ticket with its measurement.

### Measured 2026-10-20 — not a defect of the tools

The sandbox mission rebuilt from a clean folder through the actions only: `scaffold_mission` (standard, Syria, 6.31.1 from the release), `set_airbase_coalition` Incirlik and Hatay, `set_airfield_channels` Incirlik and Hatay, `add_farp` "FARP Azaz" (the sandbox's own parameters), `build_mission`.

| Point | Clean folder | Explanation |
|---|---|---|
| "injected presets into 4 aircraft" | 44 aircraft out of 173 groups with the whole shipped catalogue; of the sandbox's five types, exactly four get presets: the blue A-10C II, AH-64D, UH-1H and F-16CM templates. The F-15C has no preset radio, and the red templates match no assignment of the shipped `presets.yaml` | 4 is what the five types give; the other 55 groups of the sandbox were AI aircraft |
| "0 issues found", then an empty or absent report | `presets-validation-report.md` written, 12 issues, all on types the sandbox did not keep (F4U-1D…) | `generate_validation_report` always writes a header and a verdict; the empty and absent file came from the AI's shell commands, not from the build |
| A-10C II and AH-64D on 122.1 | 131.0, channel 1 of the shipped VHF list | the AI replaced the `primary_2` list with `01: Base-Incirlik` (tool call #152 of the export); a group's frequency is channel 1 of its first radio, so 122.1 is Incirlik's VHF as asked |

## 05 — The FARP's dynamic slots

Status: ✅ done

`add_farp` placed "FARP Azaz" (blue, Turkey, `farp_type: FARP`); `src/warehouses.yaml` named it under `farps:`; every build said "configured 10 airports, 0 ships/FARPs" and later "Ship/FARP '1' not found in the mission (farps); skipping it".
The mission's warehouses table held the FARP under `warehouses` (id 1, `dynamicSpawn = false`, no aircraft), not under `farps`.

Investigate on a clean folder: `add_farp`, then a `farps:` entry in `warehouses.yaml`, then build — does the FARP get its template links?
Fix whichever side is wrong (`add_farp`'s warehouse entry, or the build's lookup); a non-defect is written down here with its measurement.

### Measured 2026-10-20 — a defect of the build, fixed

Reproduced on a clean folder through the actions only (the sequence of ticket 04): "configured 2 airports, 0 ships/FARPs", and in the built `.miz` the FARP's warehouse `dynamicSpawn = false` with no aircraft.
Not the AI's hand edits: `add_farp` writes the right entry, under `warehouses.warehouses[<unit id>]`, where DCS keeps ships and FARPs.

Cause: a lone FARP is unit 1, so that table is keyed `[1]`, and the Lua parser reads a table keyed `1..N` back as a **list**.
The build then looked for unit 1 in a list of dicts and found nothing — the same accident as FIX-WAREHOUSES-LIST-FORM, which normalised only the `airports` table at load.
`normalize_warehouses_airports` now normalises both tables; rebuilt with the fix, the FARP has `dynamicSpawn = true` and its helicopter templates linked.

## 06 — Lighter reads

Status: ✅ done

The reads that weigh most in the export (PRD, finding 6) stay in the AI's context to the end, and are sent back on every one of its turns.

- `describe_known_limitations` with an `area` returns full entries: 46k characters for three areas. Give it the short form by default, and the full text by id.
- `list_airfields` returns 37k for Syria: return name, id, coalition and position by default, the rest on request.
- `describe_action`: the guide tells the AI to describe an action just before using it, not in batches up front.
- `describe_mission_prompt` (36–44k): measure which parts an AI needs at which step; split only if a part is clearly needed late.

Done when: each change has a test asserting the size it stays under on a real theatre or the shipped data.

### Done (2026-10-20)

- `describe_known_limitations`: `area`, `kind`, `theatre` keep the listing short; the full text by `id`/`ids` or `full`. The three largest areas read short stay under 8 000 characters (test).
- `list_airfields`: name, id, whole-metre x/y (and coalition with a mission) by default; Syria 36 732 → 20 605 characters (test: under 22 000).
- `describe_action`: the guide says to describe an action just before using it, not in batches.
- `describe_mission_prompt`, measured: in the export the AI loaded **both** prompts before asking the kind (36k + 44k). The objective prompt's sections 4–9 (21k of 34k) serve only after approval: it now comes in two parts, `scenario` by default (about 13k, test under 15k) and `build`. The open-training prompt designs from its section 4 on: not split. The action says to load one prompt, the kind chosen.

## 07 — `inspect_built_mission`

Status: ✅ done

A read-only MCP action on a built `.miz` (or a mission folder, which it resolves to its built `.miz`) that returns what the guide's post-build check needs, and nothing more:

- per airbase and FARP: coalition, the aircraft types offered as dynamic slots, and the warehouse template it is linked to;
- per aircraft type: whether presets were injected, and how many channels per radio;
- the bullseye of each coalition;
- per weather variant: the weather that differs between variants (clouds, wind, visibility, time);
- tankers and AWACS: their tasks and frequencies;
- the counters the build reports (presets injected, waypoints, warehouse links, variants), so a zero is visible.

Compact by design: one line per item, no raw mission table, so the answer stays small in the AI's context.
A field the mission does not have is reported as absent, not skipped.

Done when:
- the action is in the catalogue, with tests on a built test mission covering each section and an absent section;
- the MCP action catalogue page (`doc/`) lists it, in both languages;
- an answer on the shipped default mission stays under a size the test asserts.

### Done (2026-10-20)

`veaf_mission_mcp/inspect_built.py`, tested on the built demo mission and on a bare copy (every section `absent`); catalogue page in both languages.
Compact by grouping: the template types once per side, each base "every blue template linked (61)" rather than the list again, presets grouped by radio layout.
Measured: the shipped default mission built (standard, Syria, FARP) reads 5 169 characters; listing each base's types made 40 245.

## 08 — The guide checks through the action, never through a shell

Status: ✅ done

In `veaf_mission_mcp/data/authoring-guide.md`, *Finish: validate, then build*: "open the built `.miz` and check" becomes "call `inspect_built_mission` and check".

And one general rule, near the top where the guide says to ground every answer in the oracle: never unzip, grep or parse a `.miz` or a mission file in a shell — every read goes through an action (`describe_*`, `read_mission_file`, `inspect_built_mission`).
When no action answers a question, tell the user what could not be checked rather than improvising a parser.

The two mission prompts (`data/mission-prompts/`) are checked for the same instruction and aligned if they carry it.

Done when: the guide and prompts say it, and nothing in them still asks to open a `.miz` by hand.

### Done (2026-10-20)

The guide's rule sits right after the oracle section; *Finish* and the two prompts' checklists (both languages) check through `inspect_built_mission`, `describe_mission` and `describe_units`; a test fails when any of them asks to open a `.miz` by hand or names `veaf_libs/data/`.
