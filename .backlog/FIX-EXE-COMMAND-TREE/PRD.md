# FIX-EXE-COMMAND-TREE — the documented CLI is one nobody with the .exe can type

Status: ⬜ ready

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

- [ ] The `.exe` exposes the themed tree: `veaf-tools.exe content extract-aircraft-groups` runs
- [ ] A test asserts **both entry points expose the same set of commands**, so they cannot diverge
      again — that is the actual defect, the missing line is only its symptom
- [ ] The flat aliases keep working from both (`veaf-tools.exe extract-aircraft-groups`)

## Preferred shape, stated rather than assumed

Rather than adding the missing line to a second copy, consider making `veaf-tools.py` **call
`main()`** so there is one implementation. The duplication is what allowed the divergence, and a
test comparing the two entry points is easier to keep honest when there is only one path. If that
turns out to break the PyInstaller analysis (the entry script's imports are what PyInstaller reads
to find modules — see the comment at `veaf_build/worker.py:40`), fall back to adding the call and
say so in the PR.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The exe never builds the command tree](tickets/01-exe-misses-command-tree.md) | fix |
