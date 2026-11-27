# FEAT-VEAF-LOGS-REST-API — `veaf-logs` reads a server's logs through DCSServerBot's RestAPI

Status: ✅ done · archived 2026-11-24

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

**`veaf-logs` is the Go viewer** since [FEAT-GO-VEAF-LOGS-SHIP](FEAT-GO-VEAF-LOGS-SHIP.md) (2026-10-25, [ADR 0023](../../docs/adr/0023-veaf-logs-in-go-the-rest-in-python.md)).
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

## Results — tickets 01 to 04, 2026-10-26

- **Open question 1 settled: the lines written back hold.**
  Four real logs read through DCSServerBot's own `logreader.py` (the merged code of VEAF/DCSServerBot#3), forward by 2000 entries as `APISource` reads, written back, then `cmd/logdump` on the original and on the copy, compared record by record with `testdata/compare_dumps.py`: private1's `dcs.log` of dcs.veaf.org (9 MB, 33 requests, 63 156 entries), a local `dcs.log` (1 959), two bot logs with 40 and 12 tracebacks (1 795 and 519).
  **0 records differ.**
  No raw mode is needed on the DCSServerBot side.
- Questions 2 to 4 went as recommended: discovered logs (`/servers`, then `/node/logs` for the bot log, which also tells a bot without the log routes), the last 2000 entries at opening, the key in `api_key_file` only.
- **Different from ticket 02's sketch**: no `prefix:` key, the URL carries it (`url: https://dcs.veaf.org/serverapi`): one key less to explain.
- **500 is "retry later"**, like 503 and 504: the bot answers it for any failure while reading, and a permanent error would have stopped the tab for good.
  A 404 "disappeared while it was read" is retried too.
- **The reason a log cannot be read now shows in the status bar for every tab**, SSH and local included: until now an SSH tab whose connection dropped still said *suivi actif*.
  A local file being rotated by DCS shows *journal momentanément indisponible* for the instant it lasts.
- Found while checking the window by hand against a stand-in bot built on the real `logreader.py`: a key file of several lines made an invalid HTTP header, reported as *serveur injoignable*; such a file is now refused when the tab opens, saying the key must be alone on one line.
- The window part was checked by hand: discovery listing `fake-api › VEAF Private 1`, `VEAF Public 1`, `bot`; the bot tab showing 519 lines out of 519, as `logdump` counts them.

## Results — ticket 05 on dcs.veaf.org, 2026-10-26

- **The log routes are not reachable from the internet, on purpose.**
  The machine's Caddy (`C:/Users/veaf/caddy/Caddyfile`) lets out only the routes the web site reads, and only to the site's address (116.202.81.5); `https://dcs.veaf.org/serverapi/...` answers 404 to anyone else.
  Opening `/serverapi/instance/log*`, `/serverapi/node/log*` and `/serverapi/servers` to the viewer's users is a decision on the server (VEAF-Servers, `docs/PARE-FEU.md`), not part of this lot.
- Checked instead through an SSH tunnel to the bot's `127.0.0.1:9876` (`url: http://127.0.0.1:<port>/serverapi`, the case the configuration allows plain http for), with the key of the server's `restapi.yaml`, read-only:
  - discovery lists the six servers (`VEAF (www.veaf.org) [fr] - Privé 1`…) and `bot`;
  - opening Privé 1's live `dcs.log` (the last 2000 entries, 218 KB) takes 0.25 s, the bot log 0.12 s, a cursor read then brings nothing new;
  - read whole through the API, forward, Privé 1's `dcs.log` (9 MB, 33 requests, 1.5 s) and the bot's `dcssb-dcs-veaf-org.log.1` give, through `cmd/logdump`, the same records as the same files downloaded over SFTP: 63 156 and 1 795 records, **0 differ**;
  - an unknown server, a bad cursor and a wrong key come back as `ErrAPIUnknownLog`, `ErrCursorRefused` and `ErrAPIAuth`.
- Not seen: a tab following a mission restart (the rotation), which needs an instance restarted while a tab is open — David's call on a live server; the rotation is covered by the unit tests and by the bot's own cursor tests.
  Privé 1 had no older `dcs-*.log` that day: the older-file path was checked on the bot's rotated log.

## Results — David's check from the internet, 2026-10-26

- The log routes opened in the server's Caddy, to the technician key only (VEAF/VEAF-Servers#20); the bot's own key and no key get a 404 without a body there, which the viewer now reports as an authentication refused (#1198).
- David opened Privé 1 through `https://dcs.veaf.org/serverapi` with the technician key, then restarted the whole Privé 1 server from Discord: the tab followed the new `dcs.log`.
- Merged in #1198 (2026-10-26).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`logcore.APISource`: a Follower fed by the RestAPI](FEAT-VEAF-LOGS-REST-API.md) | ✅ |
| 02 | [`api:` servers in `~/veafmct.yaml`, instances discovered](FEAT-VEAF-LOGS-REST-API.md) | ✅ |
| 03 | [The window opens API logs and their older files](FEAT-VEAF-LOGS-REST-API.md) | ✅ |
| 04 | [`LOGS.md` / `LOGS.en.md`: reading a server's logs through its RestAPI](FEAT-VEAF-LOGS-REST-API.md) | ✅ |
| 05 | [Check on dcs.veaf.org](FEAT-VEAF-LOGS-REST-API.md) | ✅ |

One branch and one PR for the lot.

## Out of scope

- Any action on the server: the viewer reads, nothing else.
- The support bot and the Python core: neither reads a server's logs.
- The MCP server of the DCSServerBot repository ([VEAF/DCSServerBot#2](https://github.com/VEAF/DCSServerBot/pull/2)), which uses the same routes for an AI assistant.

## Tickets, in full

## 01 — `logcore.APISource`: a Follower fed by the RestAPI

Status: ✅ done

In `src/go/veaf-logs/internal/logcore/`, beside `RemoteSource`: a `Follower` whose buffer is a local mirror file, filled from the RestAPI's `/instance/log` or `/node/log` answers instead of SFTP reads.
The HTTP client lives outside `logcore` (an interface, as `SFTPClient` is), so `logcore` stays without network.

- Opening: `tail=true&lines=2000`; then each poll passes the last `cursor`, with `lines=2000`, and polls again at once while `more` is true.
- Each entry is written back as a line of its log's format: `date time LEVEL text` for a DCS log, `date time LEVEL\ttext` for a bot log, the `\n`-joined continuation lines after it; an entry with no time nor level is written as its text alone.
- `rotated` with `new_file_at`: the entries before the index end the current journal, `Fetch` reports the rotation, and the mirror starts over with the entries from the index.
  `gap`: the same, plus a flag the window shows (ticket 03).
- Errors, read from the status and the `detail` text (see the PRD):

  | Answer | Means | The source |
  |---|---|---|
  | 404 "No log file yet" | the log was never written (a new instance) | `ErrRemoteFileMissing`: waits and retries |
  | 404 server, node or file unknown | an instance renamed or removed, a file rotated away | a permanent error: no retry, the tab says it |
  | 400 on a cursor | the cursor is refused | starts over with a tail read |
  | 401, 403 | authentication refused | a permanent error with ticket 02's hint |
  | 501 | the `veaf` version, a log on another node | a permanent error, saying so |
  | 503, 504, network failure | node inactive or not answering, bot unreachable | `ErrUnavailable`: waits `retryDelay` like SFTP |

  If telling the 404s apart by their text proves brittle, ask the DCSServerBot side for an error code in the answer.

### Done when

- Tests against an `httptest` server with canned answers: opening, follow, `more`, rotation with and without `new_file_at` at 0, `gap`, each row of the error table, network failure.
- **Measured**: `cmd/logdump` on a real `dcs.log` and on the copy written back from the API's entries gives the same entries and the same categories (open question 1 of the PRD); the same for a `dcssb-*.log`.
  If not, the difference goes into the PR and the PRD, and the lot asks for a raw mode on the DCSServerBot side before going further.
- `go vet`, `gofmt` and the Go CI pass.

## 02 — `api:` servers in `~/veafmct.yaml`, instances discovered

Status: ✅ done

The `servers` block (`internal/sshlog`, `ConfigPaths`, the parser and its tests) takes a second kind of server:

```yaml
servers:
  veaf-api:
    api:
      url: https://dcs.veaf.org          # the RestAPI, behind HTTPS
      api_key_file: ~/.veaf/dcssb-api-key
      # prefix: /api                     # if the RestAPI has one
    # logs:                              # optional: narrow or rename what is discovered
    #   private1: {instance: private1}
    #   bot: {node: dcs-veaf-org}
```

- A server has either `host` (SSH) or `api`, never both; the error says which.
- Without `logs:`, the instances come from `/servers` and the bot log from `/node/logs` (the API's own node).
- The key is read from `api_key_file` when the connection opens and kept in memory only: not in `session.json`, not in an error, not in the `/bug` report (a test greps for it).
- A 403 says what to change on the server: the right key; and on DCSServerBot 3.0.5, an API key accepted from where the viewer connects on the log routes **and on `servers`**, which the discovery reads (`endpoints.<path>.security.remote: api_key` in `restapi.yaml`).
- `http://` is accepted for `127.0.0.1` and `localhost` only (an SSH tunnel); any other host needs `https://`.

### Done when

- Parser tests: an API server, a mixed config, both `host` and `api`, no `url`, a missing key file, `http://` to a remote host refused.
- Discovery tested against `httptest`: servers listed, `logs:` narrowing and renaming, a 403 with its hint.

## 03 — The window opens API logs and their older files

Status: ✅ done

- `Fichier › Ouvrir un journal distant…` lists the API servers beside the SSH ones, with their discovered instances and bot log; a tab is `veaf-api:private1`, reopened at the next launch as the SSH tabs are (`internal/logview` session order).
- `Fichier › Ouvrir un ancien journal…` on an API tab lists `/instance/logs` (or `/node/logs`) with sizes and dates, and opens the chosen file read-only: `file=<name>&tail=false`, then the cursor, chunk by chunk, with the progress the window already shows for a big local file.
- The status bar says: authentication refused (with ticket 02's hint), no log yet, instance or file unknown, log on another node (501), server unreachable, and after a `gap` "the log restarted, some lines were lost".

### Done when

- `internal/logview` tests for the session order and the tab names of API tabs.
- `--smoke` still passes; an API tab cannot be tested there, so the window part is checked by hand against a local bot or a fake API, and the PR says how.

## 04 — `LOGS.md` / `LOGS.en.md`: reading a server's logs through its RestAPI

Status: ✅ done

The `#remote` section of `doc/mission-maker/LOGS.md` and `LOGS.en.md` gains the API way, FR and EN, beside SSH:

- what it needs on the server: DCSServerBot with the log routes (version to state once released), the RestAPI plugin and its key, a reverse proxy with HTTPS, the `restapi.yaml` endpoint rules for an API key from the internet;
- the `api:` block of `~/veafmct.yaml`, the key file;
- what differs from SSH: no SSH account, read-only, the history a tab opens with (the last 2000 entries), the level padding not kept;
- security: the key in a file only the user can read, never the API without HTTPS, logs carry player names and IP addresses.

Plus the `CHANGELOG.md` entry.

### Done when

- Both languages say the same thing; one sentence per line in what is written or rewritten.

## 05 — Check on dcs.veaf.org

Status: ✅ done (2026-10-26, see the PRD)

Blocked until the log routes run on dcs.veaf.org: [VEAF/DCSServerBot#3](https://github.com/VEAF/DCSServerBot/pull/3) merged into our `veaf` branch and deployed (David's call), or DCSServerBot 3.0.5 with #1.
Read-only; David, or a session with his go.

- Open a running instance's `dcs.log` and the bot's log through the API, leave them open across a mission restart: the tab follows the new `dcs.log`, the end of the old one is not lost.
- Open an older `dcs-YYYYMMDD-HHMMSS.log`.
- Compare with the same instance opened over SSH: same entries, same categories, for the same span.

### Done when

- The three points seen, the result written in the PRD's findings.
