# 07 — A voice on SRS

Status: ⬜ ready

When Claude plays blue and warns the players concerned (D3), the warning is also spoken on their SRS frequency.

## Where the voice has to start

`DCS-SR-ExternalAudio.exe` takes a port (`-p`, default 5002) and **no server address** (its `--help`, version 1.0.0, read 2026-10-08): it always speaks to the SRS server on its own machine.
The MCP server runs on David's PC while the squadron's SRS servers run on dcs.veaf.org (David, 2026-10-08), so the executable has to be run **on the SRS host**, not where the MCP runs.
Measured 2026-10-08 on dcs.veaf.org: `C:\Program Files\DCS-SimpleRadio-Standalone\ExternalAudio\DCS-SR-ExternalAudio.exe` is installed, and five `SRS-Server-Commandline` processes run, one per DCS instance, each on its own port.

## How

- `live_message` gains an optional `voice`: a frequency (or several), a modulation, and a station name ("Magic", "Darkstar", "Kutaisi Tower"); the coalition is the message's.
- The arguments are the ones `veafRadio._transmitViaSRS` already uses: `-f` frequencies, `-m` modulations, `-c` coalition, `-p` port, `-n` name, plus the culture and voice matching the mission's language (`fr-FR` / Hortense exists on DAVID-BUREAU; on the server, to be listed with `--help`).
- **SRS on the same machine as the MCP** (a mission David hosts): run the executable directly, with an argument list, never a shell.
- **SRS on dcs.veaf.org**: run it there over the SSH access the tools already use (`veaf-logs`). The text goes as a **file** uploaded by SFTP and read with `-I`, so nothing the message holds reaches the remote shell; the port is the one of the instance the mission runs on, read from that instance's SRS server config rather than typed.
- No SRS server, no executable, no SSH: the text still goes, and the action says the voice did not.
- The frequencies come from the mission when Claude does not give them: the AWACS's or the tower's, read through `live_situation`.

Not through the mission: the in-mission path is mute on both machines today (the PRD's table), and making it speak means handing `os` to the missions of a public server — David's call, taken up by [`FEAT-CONVOY-UNDER-FIRE`](../../FEAT-CONVOY-UNDER-FIRE/PRD.md), whose convoy must speak with nobody in the conversation.

## Done when

- Tests: the argument list built for one and for two frequencies; the remote command built with the text in a file, never in the command line; the port resolved from an instance's SRS config; the missing executable or the failed SSH reported without failing the text.
- Heard once before the PR leaves: a phrase spoken on 251 AM, in French, on an SRS server of dcs.veaf.org — on an instance nobody is flying, chosen with David.
