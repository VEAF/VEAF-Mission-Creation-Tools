# 02 — Make `veaf-tools.spec` honest — or delete it

Status: ⬜ ready
Type: chore

## Why

[`veaf-tools.spec`](../../../veaf-tools.spec) declares four `datas` entries, including
`('src\\python\\veaf-tools\\veaf_libs\\data\\convert-profiles', 'veaf_libs\\data\\convert-profiles')`.

**The build never reads that file.** `BuildAndReleaseWorker._build_pyinstaller_executable`
invokes `pyinstaller` with its own `--add-data` list from `_veaf_tools_extra_data`. The `.spec`
files are leftovers from an earlier build path.

That mismatch already cost real time: the conversion profiles were missing from the shipped
executable (`unknown conversion profile: foothold`, fixed in
`FEAT-FOOTHOLD-RELEASE-INTAKE-005`), and the obvious place to check — the `.spec` — said they
were bundled. The same trap applies to `veaf-tools-updater.spec`.

Worse, the two lists have **silently diverged**: the `.spec` lists four entries while
`_veaf_tools_extra_data` bundles a dozen. Anyone reading the `.spec` gets a wrong picture in
both directions.

## Options

| Option | Cost | Effect |
|---|---|---|
| **Delete both `.spec` files** | trivial | one source of truth (`_veaf_tools_extra_data`); loses the ability to run `pyinstaller veaf-tools.spec` by hand |
| **Generate the `.spec` from `_veaf_tools_extra_data`** | medium | keeps a runnable spec, cannot drift; more build machinery |
| **Build *from* the `.spec`** and drop the `--add-data` list | medium-high | the spec becomes authoritative and readable; but the data list is currently computed (paths conditional on `path.exists()`, generated JSON files), which a static spec cannot express |

Recommendation: **delete**, unless someone relies on invoking PyInstaller directly. The
computed nature of the data list (generated `veaf_modules_list.json` / `veaf-shortcuts.json`
paths passed in as arguments) is what makes the third option awkward — that is the reason the
code path won in the first place.

## Tasks

- [ ] Confirm nothing invokes `pyinstaller *.spec` — CI workflows, docs, release skill, and any
      developer instructions.
- [ ] Apply the chosen option for **both** `veaf-tools.spec` and `veaf-tools-updater.spec`.
- [ ] If deleting: leave a one-line pointer in `doc/developer/` (or `veaf_build/worker.py`'s
      docstring) saying `_veaf_tools_extra_data` is the list of bundled data, so the next person
      looking for "what ships in the exe" finds it immediately.
- [ ] Build the executable afterwards and confirm the bundled data is unchanged — the regression
      guards in `test_build_standalone.py` cover the list, but the binary is the proof.
- [ ] CHANGELOG (developer-facing).

## Notes

Whatever the choice, the acceptance criterion is the same: **a developer asking "what data ships
in the exe?" must find exactly one answer.** Today they find two, and the wrong one is more
prominent.
