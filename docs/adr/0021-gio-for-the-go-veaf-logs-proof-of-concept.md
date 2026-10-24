---
status: proposed
---

# Gio as the UI toolkit of the Go `veaf-logs` proof of concept

Lot: [POC-GO-VEAF-LOGS](../../.backlog/POC-GO-VEAF-LOGS/PRD.md).
Measured on DAVID-BUREAU (Windows 11), 2026-10-23 and 24, Go 1.27.3, gcc (MinGW) 16.2.

## Context

David wants a real native binary for VMCT.
Rewriting all of `veaf-tools` is out of proportion for an unproven bet, so the proof of concept is `veaf-logs`: a DCS journal viewer, PySide6 + paramiko, shipped as a PyInstaller executable.
The UI toolkit is the one choice that sets the weight of the binary and the cost of the rewrite, so it was settled by measurement.

## What was measured

Each toolkit got the same minimal program: a window with a virtualised list of 1 000 000 rows, built with `-ldflags "-s -w -H windowsgui"`.

| | Executable | Build | Window visible | Scrolling 1 M rows | Notes |
|---|---|---|---|---|---|
| **Gio** v0.10.3 | **8.5 MB** | **7.5 s** | 0.27 s warm, 1.0 s first launch | 1.9 ms/frame (300 frames, layout, material scrollbar included) | pure Go, no cgo |
| Fyne v2.8.2 | 23.7 MB | 4 min 05 s | 0.25 s warm, 0.9 s first launch | not measured | needs cgo (gcc) |
| WebView2 (`go-webview2`, stand-in for Wails) | 3.1 MB | seconds | native window at 0.03 s, page content not timed | not measured | the list is HTML/JS: a second language; depends on the WebView2 runtime |
| *veaf-logs Python (reference)* | *47.2 MB* | — | *2.1 s* | — | — |

Limits of this table, stated so that nobody reads more into it than it holds:

- "Window visible" is the moment the process owns a top-level window, not the first painted frame; it is comparable between Gio and Fyne, not with WebView2.
- Fyne scrolling and a real Wails build were not measured: Fyne because its size and its four-minute cgo build were enough to rule it out for this use, Wails because it needs the frontend toolchain (node) and a second language.
- Gio's figure comes from the spike; the real window (below) scrolls at 0.7 ms/frame including the GPU frame.

## Decision

Use Gio for the proof of concept.

- Smallest pure-Go option that renders its own list: no cgo, no external runtime, a 7-second build.
- Full control of the list, which is what a journal viewer is made of: only the visible rows are laid out and decoded, whatever the length.
- A second language (HTML/JS, as Wails would impose) is exactly what the rewrite is trying to avoid.

## Result on the real application

`src/go/veaf-logs`, same journal (130 MB, 954 086 entries) on both sides:

| | Python | Go |
|---|---|---|
| Executable | 47.2 MB | 9.5 MB |
| Window visible | 2.1 s | 0.3 s |
| Index the journal | 13.2–13.6 s | 2.3–2.5 s (window usable after 0.35 s, indexing in the background) |
| Search "ctld" / "error" (same hits: 187 082 / 128 478) | 0.71 / 0.72 s | 0.08 / 0.11 s |
| Scrolling | — | 0.7 ms/frame |
| Memory with the journal open | 166 MB | 220 MB |
| Classification parity | reference | 0 difference over 958 000 entries and the synthetic corpus |

Memory is the one figure where Go loses; its cause was not investigated.

## Consequences

- **Go's `regexp` is slower than Python's `re` on these patterns.** A direct port indexed the journal in 17–21 s, slower than Python's 13 s.
  A literal prefilter (`bytes.Contains` on the text every match must contain, derived from the pattern) in front of each regexp brought it to 2.5 s without changing a result.
  Any further port of regexp-heavy code has to budget for this work.
- **Gio pitfall:** scrolling a list before its first layout made the first frame take over ten seconds at 100 000 rows (measured; cause not investigated).
  The application never scrolls before the first layout; `ScrollToEnd` is safe.
- **`rules.json` stays the single source.** The Go module embeds a copy, and `TestEmbeddedRulesAreThePythonOnes` fails as soon as the two differ.
- **Nothing ships, and nothing runs it.** The module is not built by `release.yml`, the Python viewer is untouched, and no workflow runs the Go tests yet: the guard on the `rules.json` copy and the parity test only protect anyone who runs `go test`. A CI job (path-filtered, like the others) is part of any follow-up that keeps the module.
- **Remote journals** work (SSH + SFTP, mirror and rotation as in `remote.py`), checked against an in-process server and, read-only, against dcs.veaf.org. Not handled: a host-key prompt (an unknown host is refused), the Windows OpenSSH agent pipe, keys protected by a passphrase outside an agent.
- **Not done by the proof of concept:** `analysis`, `report`, `proposals`, `excerpt`, the filters beyond a plain text search (glob and regex modes, tri-state categories, context lines), Linux and macOS builds of the window.

## Alternatives considered

- **Fyne:** works, but 23.7 MB, a four-minute cgo build, and no advantage for this use.
- **Wails:** the smallest binary of the three (3.1 MB for the stand-in), but it makes the project two-language and relies on an installed runtime.
- **Not doing it:** a valid outcome; the numbers above are what it would give up.
