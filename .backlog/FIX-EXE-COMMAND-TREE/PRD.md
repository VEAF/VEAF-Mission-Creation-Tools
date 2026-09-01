# FIX-EXE-COMMAND-TREE — the documented CLI is one nobody with the .exe can type

Status: ✅ done

Origin: VEAF meeting, 2026-08-30. Verified on `origin/develop` at `c14e79e2`.

## The defect

The themed command tree (`mission`, `convert`, `content`, `cockpit`, `dcs`) has been in the code
since 6.14.0 and `doc/CLI_REFERENCE` documents it. It is built by `build_cli_tree(app)`, called in
exactly one place:

| Entry point | Builds the tree | Who uses it |
|---|---|---|
| `veaf_tools/app.py::main()` (Poetry script) | **yes**, `app.py:66` | developers running `poetry run veaf-tools` |
| `src/python/veaf-tools/veaf-tools.py` (PyInstaller entry, `veaf_build/worker.py:571`) | **no** | **every mission maker**, who has the `.exe` |

So `veaf-tools.exe content extract-aircraft-groups` does not exist, while
`poetry run veaf-tools content extract-aircraft-groups` works. The flat names work everywhere —
they survive as hidden aliases inside the tree, deliberately — which is why nothing broke loudly.

The two entry points are near-identical copies of each other. `veaf-tools.py` reproduces the
`--lang` pre-parse, the command registration, the TUI bridge and the auto-pause; it just never
grew the `build_cli_tree` call `main()` gained.

## Definition of done

- [x] The `.exe` exposes the themed tree: `veaf-tools.exe content extract-aircraft-groups` runs
- [x] A test asserts **both entry points expose the same set of commands**, so they cannot diverge
      again — that is the actual defect, the missing line is only its symptom
- [x] The flat aliases keep working from both (`veaf-tools.exe extract-aircraft-groups`)

## Preferred shape, stated rather than assumed

Rather than adding the missing line to a second copy, consider making `veaf-tools.py` **call
`main()`** so there is one implementation. The duplication is what allowed the divergence, and a
test comparing the two entry points is easier to keep honest when there is only one path. If that
turns out to break the PyInstaller analysis (the entry script's imports are what PyInstaller reads
to find modules — see the comment at `veaf_build/worker.py:40`), fall back to adding the call and
say so in the PR.

## Outcome

The preferred shape held: `veaf-tools.py` calls `main()`, and **no** fallback was needed.
PyInstaller reads `import` statements inside function bodies too, so the imports `main()`
performs are followed exactly as they were when they sat in the entry script. Verified by
building the real binary (`poetry run veaf-build build-standalone`) and running
`veaf-tools.exe content extract-aircraft-groups --help`, the flat alias, and
`generate-config` — which writes a real file, so the lazily-resolved `mission_builder`
package still reaches the bundle. The `exe-smoke` CI job runs the grouped and flat forms now.

One thing the entry script keeps, and must: it applies `--lang` **before** importing
`veaf_tools.app`. The `help=` strings are `t()` calls frozen at import time and Typer's
`--help` is eager, so a language set any later comes too late. That pre-parse moved into
`veaf_libs.i18n.set_language_from_argv()`, which both entry points call — it was the other
copied block.

Found in passing, out of scope, opened separately: the packaged **Windows** executable exits
1 even when the command succeeded (`--help`, `about`, a successful `generate-config`), on a
released 6.x binary as well as a freshly built one. The Linux binary exits 0, which is why
the CI smoke job is green.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The exe never builds the command tree](tickets/01-exe-misses-command-tree.md) | fix |
