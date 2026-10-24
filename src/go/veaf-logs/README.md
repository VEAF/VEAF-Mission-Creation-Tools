# veaf-logs (Go)

The DCS journal viewer rewritten in Go as the same program as the Python one — tabs, menus, panels, profiles, filters, analysis — milestone by milestone.
Nothing here is shipped yet; see [FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](../../../.backlog/FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL/PRD.md) and, for the window, [ADR 0022](../../../docs/adr/0022-ui-toolkit-for-the-go-veaf-logs.md).

- `internal/logcore`: the core without UI (rule catalogue, header formats, compact index, search, filters, tail with rotation detection, crash archives). A port of `veaf_logs` (Python), which remains the reference.
- `internal/sshlog`: SSH + SFTP connection (key, agent, `known_hosts`) and the `servers` block of `~/veafmct.yaml`; the window uses it again from J4.
- `internal/logview`: what the window shows, without the window — the document behind a tab, the cells, the copied text, the tab strip's logic. Plain Go, tested.
- `internal/ui`: the window, on [walk](https://github.com/tailscale/walk) (native Win32), and `internal/ui/dark` its dark theme. Windows only.
- `cmd/veaf-logs`: the executable; `rsrc_windows_amd64.syso` holds its manifest and icon (`go generate ./cmd/veaf-logs` rebuilds it).
- `cmd/logdump`: indexes a journal and writes the parity dump.
- `testdata`: the synthetic parity corpus and the golden dumps written by the Python implementation.

```powershell
cd src/go/veaf-logs
go test ./...
go build -ldflags "-s -w -H windowsgui" -o veaf-logs.exe ./cmd/veaf-logs
.\veaf-logs.exe C:\path\to\dcs.log
```

Without a path it opens `Saved Games\DCS\Logs\dcs.log`, if there is one.
`--smoke` opens the paths, waits for their index, prints `window=… indexed=… entries=…` and the closing time, then exits: build without `-H windowsgui` to see it, as the CI does.

## Keeping the Go and Python sides equal

- `internal/logcore/rules.json` is a copy of `src/python/veaf-tools/veaf_logs/rules.json`; a test fails when they differ.
- The header formats of `internal/logcore/formats.go` are a copy of `veaf_logs/parser.py` (they are not in `rules.json`). The parity test is what catches a drift: after changing the Python formats or `rules.json`, regenerate the corpus and the goldens, then run the Go tests.
- `internal/logcore/filters.go` is a port of `veaf_logs/filters.py`, checked the same way: `gen_golden.py` also writes `golden/*.filters.jsonl`, the visible entries of every enumerated filter case as the Python `evaluate` returns them. Where Go's regexp and Python's `re` cannot agree, `TestKnownDivergencesFromPython` pins the difference.
- The `Go CI` workflow runs `gofmt`, `go vet`, `go test` and the executable in `--smoke` mode on Windows, and regenerates the goldens to fail when they are stale. The corpus is committed (`.gitattributes` keeps its bytes as they are: it holds carriage returns and invalid UTF-8 on purpose).
- `VEAF_LOGS_BIG=<journal> go test ./internal/logcore -run BigJournal -v` and `poetry run python src/go/veaf-logs/testdata/time_filters.py <journal>` time the filters on a real journal on both sides, and print a digest of the visible entries to compare.

```powershell
poetry run python src/go/veaf-logs/testdata/gen_golden.py
cd src/go/veaf-logs
go test ./...
```

To compare on a real journal, from the repository root: `poetry run python src/go/veaf-logs/testdata/dump_python.py <log> py.jsonl`, `go run ./cmd/logdump <rules.json> <log> go.jsonl` (in the module), then `python src/go/veaf-logs/testdata/compare_dumps.py py.jsonl go.jsonl`.
