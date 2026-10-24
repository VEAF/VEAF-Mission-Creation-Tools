# veaf-logs (Go proof of concept)

A rewrite of the DCS journal viewer in Go, to find out whether a native binary keeps its promises: small, quick to start, and giving the same result as the Python viewer.
Nothing here is shipped; see [POC-GO-VEAF-LOGS](../../../.backlog/POC-GO-VEAF-LOGS/PRD.md) and [ADR 0021](../../../docs/adr/0021-gio-for-the-go-veaf-logs-proof-of-concept.md).

- `internal/logcore`: the core without UI (rule catalogue, header formats, compact index, search, tail with rotation detection). A port of `veaf_logs` (Python), which remains the reference.
- `cmd/veaf-logs`: the window ([Gio](https://gioui.org)).
- `cmd/logdump`: indexes a journal and writes the parity dump.
- `testdata`: the synthetic parity corpus and the golden dumps written by the Python implementation.

```powershell
cd src/go/veaf-logs
go test ./...
go build -ldflags "-s -w -H windowsgui" -o veaf-logs.exe ./cmd/veaf-logs
.\veaf-logs.exe C:\path\to\dcs.log
```

Without a path it opens `Saved Games\DCS\Logs\dcs.log`.
`--png out.png [--query TEXT]` renders the window off screen into a PNG; `--bench` prints the time to the first frame and to the end of indexing.

## Keeping the Go and Python sides equal

- `internal/logcore/rules.json` is a copy of `src/python/veaf-tools/veaf_logs/rules.json`; a test fails when they differ.
- The header formats of `internal/logcore/formats.go` are a copy of `veaf_logs/parser.py` (they are not in `rules.json`). The parity test is what catches a drift: after changing the Python formats or `rules.json`, regenerate the corpus and the goldens, then run the Go tests.

```powershell
poetry run python src/go/veaf-logs/testdata/gen_golden.py
cd src/go/veaf-logs
go test ./...
```

To compare on a real journal, from the repository root: `poetry run python src/go/veaf-logs/testdata/dump_python.py <log> py.jsonl`, `go run ./cmd/logdump <rules.json> <log> go.jsonl` (in the module), then `python src/go/veaf-logs/testdata/compare_dumps.py py.jsonl go.jsonl`.
