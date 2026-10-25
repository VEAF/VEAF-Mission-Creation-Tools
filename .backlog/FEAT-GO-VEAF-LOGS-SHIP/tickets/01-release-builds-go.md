# 01 — The release builds and publishes the Go `veaf-logs.exe`

Status: ✅ done

`release.yml`'s Windows job builds `src/go/veaf-logs/` (Go toolchain, version stamped as the Python build stamps it) instead of running PyInstaller on `veaf-logs.spec`, and uploads the result under the same asset name, so `published-latest` and whatever `veaf-tools` reads to update it keep working.
`veaf-build build-logs` builds the Go executable, or goes, whichever the release pipeline needs.
Done when a release dry run produces a `veaf-logs.exe` that opens a journal, and the updater finds it.
