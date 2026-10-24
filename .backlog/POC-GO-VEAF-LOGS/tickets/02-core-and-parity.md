# 02 — Go core and parity proof

Status: ✅ done — 2026-10-23
Type: feature

Port `rules`, the header formats, the compact index (`store`) and the file buffer (read by offset, never held open) to Go in `src/go/veaf-logs/`, loading the unchanged `rules.json`.

Done when a Go test compares, entry by entry, level, source, label, module, noise families, timestamp, subsystem, message and continuation count with a golden dump produced by the Python implementation, on a corpus covering the five header formats, and when the counters per level, source and noise family match too.
The same dump is also compared on real `dcs.log` files.
