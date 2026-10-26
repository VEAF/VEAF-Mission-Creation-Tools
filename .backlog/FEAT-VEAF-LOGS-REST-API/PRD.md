# FEAT-VEAF-LOGS-REST-API — `veaf-logs` reads a server's logs through DCSServerBot's RestAPI

Status: ⬜ ready

David, 2026-10-26.
On 2026-10-18, finding out why a dcs.veaf.org server would not restart took about twenty throwaway PowerShell scripts over SSH, to read the instances' `dcs.log`, the bot's log and their rotated copies.
The same week, another Claude session with a raw SSH shell killed a DCS process with `Stop-Process`, and another server got a 401 from ED.
David decided to build log reading into DCSServerBot's RestAPI, for everyone running the bot, and to have `veaf-logs` use it.
Written up 2026-10-26, once the API's design was validated; to be done later.

## The need

A mission maker or a server admin follows a server's `dcs.log` (or the bot's log) in `veaf-logs`, with its filters, rules and profiles, **without an SSH account on the server**.
The bot's RestAPI already runs on the server, behind HTTPS; an API key is all the viewer needs.
SSH stays for those who have it; the API becomes the way for everyone else.

What it is not: a way to act on the server.
The viewer only reads.

## What exists — read on `develop` at `26aff9de`, 2026-10-26

**`veaf-logs` is the Go viewer** since [FEAT-GO-VEAF-LOGS-SHIP](../FEAT-GO-VEAF-LOGS-SHIP/PRD.md) (2026-10-25, [ADR 0023](../../docs/adr/0023-veaf-logs-in-go-the-rest-in-python.md)).
The Python `veaf_logs` keeps only its windowless core, for the support bot and the parity tests; its SSH reader (`remote.py`) left with the PySide6 window.
This lot is therefore Go work in `src/go/veaf-logs/`, and touches no Python.

**Remote journals today go through SSH + SFTP.**

- `internal/sshlog` opens the connection (key, agent, `known_hosts`) and reads the `servers` block of `~/veafmct.yaml`: per server a host, a user, an optional key, and `logs:` mapping an instance name to the remote **path** of its `dcs.log` (or of the bot's log).
- `logcore.RemoteSource` implements `logcore.Follower` over a `MirrorBuffer`: a local temporary copy of the remote file, extended at each poll (one stat, then the new bytes, 8 MiB at most per poll), because the viewer reads by offset, one read per displayed line.
  A remote file that shrank is a rotation: the mirror starts over and the index restarts.
- The user doc is `doc/mission-maker/LOGS.md` and `LOGS.en.md`, section *Journal d'un serveur distant* (`#remote`): it asks for the Windows OpenSSH server and an administrator key on the server.

**The RestAPI routes**, not merged yet: [VEAF/DCSServerBot#1](https://github.com/VEAF/DCSServerBot/pull/1) on the fork's `development` (the version to propose to SpecialK for 3.0.5), and [VEAF/DCSServerBot#3](https://github.com/VEAF/DCSServerBot/pull/3), the same routes for our `veaf` branch (3.0.4.27, local node only), which is how they reach dcs.veaf.org before 3.0.5 (David, 2026-10-26).

| Route | What |
|---|---|
| `GET /instance/logs?server_name=` | the files of a server's DCS log, newest first: `dcs.log`, `dcs.log.old`, the `dcs-YYYYMMDD-HHMMSS.log` copies the bot makes at shutdown (name, size, modified, live) |
| `GET /instance/log?server_name=&…` | read a DCS log |
| `GET /node/logs?node_name=` | the files of a node's bot log (`dcssb-<node>.log`, `.1`…`.5`) |
| `GET /node/log?node_name=&…` | read a bot log |

- Reading parameters: `file` (a name from the listing; a path is never accepted), `contains` (repeatable), `level`, `since`, `until`, `lines` (2000 at most), `tail`, `cursor`.
- The answer is **entries, not bytes**: `{time, level, text}`, the lines without a timestamp that follow an entry (a traceback, a multi-line Lua error) joined to its text with `\n`.
- Each answer carries a `cursor`; passed back, it returns only what was written since.
  Through a rotation it returns the end of the old file, then the new file, with `rotated: true` and `new_file_at` (the index in `lines` where the new file starts); `gap: true` if the old file is gone.
- Bounds: 16 MiB read and 1 MiB returned per request; `more: true` when a limit is hit.
- Auth, on the `veaf` version (#3): the `api_key` of `restapi.yaml` protects every route, the log routes exist only when it is set, and the key is all a client needs.
  On 3.0.5 (#1): the log routes need at least an API key, even on the loopback, but every route asks a JWT from the internet by default, so the server's `restapi.yaml` must allow `api_key` from there (`endpoints.<path>.security.remote: api_key`) on the log routes **and on `/servers`**, which the discovery reads.
- Errors: 400 for a bad parameter or cursor; 404 for an unknown server, node or file name, **or** a log not written yet (the `detail` text tells which); 501 on the `veaf` version for a server or bot log on another node; 503 for an inactive node and 504 for a node that does not answer, on 3.0.5.
  At a shutdown the bot **copies** `dcs.log` (`dcs-YYYYMMDD-HHMMSS.log`), it does not move it: a stopped instance still has its `dcs.log`, and a 404 does not mean "instance stopped".

## What the lot delivers

1. **A second kind of remote source** (ticket 01): `logcore.APISource`, a `Follower` whose mirror is filled from the API's entries, each written back as a line in its log's own header format, polled with the cursor, starting a new journal at `new_file_at` after a rotation.
2. **The configuration** (ticket 02): an `api:` server in the `servers` block of `~/veafmct.yaml` (URL and key file), its instances and nodes found by the API, the key never written anywhere else.
3. **The window** (ticket 03): API servers in `Fichier › Ouvrir un journal distant…` beside the SSH ones, the older files of a log openable, the API's answers turned into the status bar's messages.
4. **The documentation** (ticket 04): the `#remote` section of `LOGS.md` / `LOGS.en.md`, FR and EN, with the server-side setup and the security notes.
5. **The check on dcs.veaf.org** (ticket 05): David, read-only, once the routes are deployed there.

## Open questions, with the default recommendation

1. **Lines written back from entries, or a raw mode in the API.**
   The viewer indexes bytes in the original format; the API returns parsed entries.
   *Default*: write the lines back (`date time LEVEL text` for DCS, `date time LEVEL\ttext` for the bot, continuation lines after them): the `dcs` and `dcssb` header patterns of `internal/logcore/formats.go` accept them (one space where DCS pads the level, a tab for the bot).
   What is lost is the level's padding and the carriage returns, which no rule reads.
   Ticket 01 proves it with `cmd/logdump` on a real `dcs.log` and on its written-back copy: same entries, same categories.
   If it does not hold, a `raw=true` mode in the API (bytes from an offset, with the same cursor) is a small change to propose on the DCSServerBot side.
2. **How the instances are found.**
   *Default*: discovered: `/servers` gives the servers, `/node/logs` the bot log of the API's node; an optional `logs:` list in the config narrows or renames them.
3. **How much history a tab opens with.**
   The API does not page backwards: a tail read gives the last entries, a cursor goes forward.
   *Default*: the last 2000 entries at opening (`tail=true&lines=2000`), then the cursor; *Fichier › Ouvrir un ancien journal* reads a whole older file forward, chunk by chunk.
4. **Where the key lives.**
   *Default*: `api_key_file` in the server's block (a file only the user can read); never the key itself in `veafmct.yaml`, never in `session.json`, never in a message or the `/bug` report.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`logcore.APISource`: a Follower fed by the RestAPI](tickets/01-api-source.md) | ⬜ |
| 02 | [`api:` servers in `~/veafmct.yaml`, instances discovered](tickets/02-config-and-discovery.md) | ⬜ |
| 03 | [The window opens API logs and their older files](tickets/03-window.md) | ⬜ |
| 04 | [`LOGS.md` / `LOGS.en.md`: reading a server's logs through its RestAPI](tickets/04-docs.md) | ⬜ |
| 05 | [Check on dcs.veaf.org](tickets/05-live-check.md) | ⬜ |

One branch and one PR for the lot.

## Out of scope

- Any action on the server: the viewer reads, nothing else.
- The support bot and the Python core: neither reads a server's logs.
- The MCP server of the DCSServerBot repository ([VEAF/DCSServerBot#2](https://github.com/VEAF/DCSServerBot/pull/2)), which uses the same routes for an AI assistant.
