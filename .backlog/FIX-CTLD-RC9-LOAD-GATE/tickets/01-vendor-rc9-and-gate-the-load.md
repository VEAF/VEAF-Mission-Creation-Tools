# 01 — vendor CTLD rc9 and gate the community-script load

Status: 🔄 in-progress

See the PRD for the root cause and why the whole VEAF framework goes down with CTLD.

## What changes

1. **`src/scripts/community/CTLD.lua`** — replace with the `CTLD.lua` asset from the
   [`published-v2.0.0-rc9`](https://github.com/VEAF/CTLD/releases/tag/published-v2.0.0-rc9) release.
   Verbatim vendoring: download the asset, do not hand-edit, do not rebuild locally.
2. **`vendored.yaml`**, `ctld` entry: `pinned: "2.0.0-rc9"` and the watch's
   `pinned: "published-v2.0.0-rc9"`.
3. **`test/lua/test_community_scripts_load.lua`** — new. Loads each vendored community script with
   `dcs_mocks.lua` and fails if the main chunk raises.
4. **`CHANGELOG.md`** `[Unreleased]`, appended at the **end** of the section.

## Watch out

- **Do not rebuild `CTLD.lua` from the CTLD sources.** The manifest says `vendoring: verbatim`, and
  `test_vendored_pins_match_the_files.py` compares `ctld.VERSION` in the file against `pinned:` — a
  locally built file can carry the right version and still differ from the published asset.
- **One test per script, not a loop.** A loop stops at the first raise and the report names the
  loop; seven named tests name the culprit.
- **TUM stays out, explicitly.** It raises on load without territory zones, which is its documented
  contract and the reason it is opt-in. Written into the test file as a reasoned exclusion with the
  measured traceback — never a silent skip. See the PRD.
- The scripts load into **one** Lua state, in one process (`veaf_build/lua_tests.py` runs each
  `test_*.lua` in its own subprocess, so there is no bleed into the other suites). That is the
  faithful shape: a mission loads them all into one state too.
- Do not bump the version anywhere (`pyproject.toml`, the two plugin manifests) — §9.5.

## Acceptance

- The new test is **red** against the currently vendored rc8, with the production traceback in the
  failure message, and **green** after the rc9 file is dropped in. Both observed.
- `poetry run test-lua` green.
- `poetry run check-vendored` reports 0 drifted; `test_vendored_pins_match_the_files.py` green.
- Python quality gate green (`ruff check` + `ruff format --check` + `mypy`).
- A mission built from this branch with CTLD enabled shows the VEAF radio menu again — **needs
  DCS**, see below.

## Tests

`test/lua/test_community_scripts_load.lua`, as above. Already verified red against rc8:

```
Ran 7 tests in 0.038 seconds, 6 successes, 1 failure
  TestCommunityScriptsLoad.test_ctld_loads — CTLD.lua must load without raising:
    CTLD configuration is not loaded — call ctld.initialize() before …
```

Note the other six pass against the current pins, so the gate is measuring something real from day
one rather than being green by construction.

## Needs DCS

The end-to-end confirmation — build a mission, fly it, see the F10 menu — cannot be done from a
workstation without the game. The Lua gate proves the file loads outside DCS, which is exactly the
failure that was reported, and CTLD's own CI now proves the same on every build. Worth one in-game
check when convenient; not a blocker for shipping 6.22.1, since 6.22.0 is broken for everyone right
now and this restores the rc7 behaviour plus the upstream fix.
