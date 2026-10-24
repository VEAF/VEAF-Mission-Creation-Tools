# 03 — The Go parity tests run in CI, on a checkout that has the corpus

Status: ⬜ ready

Found 2026-10-24 while starting J1: the synthetic parity corpus `src/go/veaf-logs/testdata/corpus/*.log` is caught by the root `.gitignore` rule `*.log`, so a fresh checkout fails `go test` with "no corpus found", and no workflow runs `go test` at all.
The parity of the proof of concept is therefore checked by nobody but the person who regenerates the corpus.

## Done when

- The corpus is committed (it is synthetic, written by `gen_golden.py`: no player name, no path), through a `.gitignore` exception.
- A workflow runs `go vet` and `go test ./...` in `src/go/veaf-logs` when that module, the Python `veaf_logs` it mirrors or the workflow changes; it does not touch `release.yml`.
- A check that the committed goldens are what `gen_golden.py` writes today, so a change of the Python reference without regenerating fails in CI.
