# 01 — `logcore.APISource`: a Follower fed by the RestAPI

Status: ⬜ ready

In `src/go/veaf-logs/internal/logcore/`, beside `RemoteSource`: a `Follower` whose buffer is a local mirror file, filled from the RestAPI's `/instance/log` or `/node/log` answers instead of SFTP reads.
The HTTP client lives outside `logcore` (an interface, as `SFTPClient` is), so `logcore` stays without network.

- Opening: `tail=true&lines=2000`; then each poll passes the last `cursor`, with `lines=2000`, and polls again at once while `more` is true.
- Each entry is written back as a line of its log's format: `date time LEVEL text` for a DCS log, `date time LEVEL\ttext` for a bot log, the `\n`-joined continuation lines after it; an entry with no time nor level is written as its text alone.
- `rotated` with `new_file_at`: the entries before the index end the current journal, `Fetch` reports the rotation, and the mirror starts over with the entries from the index.
  `gap`: the same, plus a flag the window shows (ticket 03).
- Errors map to the existing `ErrUnavailable` family: 404 on the live file is `ErrRemoteFileMissing` (instance stopped), 403 is an authentication error with the hint of ticket 02, a network failure waits `retryDelay` like SFTP.

## Done when

- Tests against an `httptest` server with canned answers: opening, follow, `more`, rotation with and without `new_file_at` at 0, `gap`, 404, 403, network failure, a cursor the server refuses (400: start over with a tail read).
- **Measured**: `cmd/logdump` on a real `dcs.log` and on the copy written back from the API's entries gives the same entries and the same categories (open question 1 of the PRD); the same for a `dcssb-*.log`.
  If not, the difference goes into the PR and the PRD, and the lot asks for a raw mode on the DCSServerBot side before going further.
- `go vet`, `gofmt` and the Go CI pass.
