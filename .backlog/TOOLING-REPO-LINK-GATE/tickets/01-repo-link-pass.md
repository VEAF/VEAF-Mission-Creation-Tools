# 01 — Repo-wide relative-link pass in `docs_check`

Status: ✅ done
Type: feat
Files: `veaf_build/docs_check.py`, `test/python/veaf_build/`

## Behaviour

A second, deliberately narrow pass beside `check_docs`, over markdown **outside** `doc/`:
`.backlog/`, `docs/`, `.github/`, `plugin/` and the root `*.md`.

One rule only: **a relative link's target must exist.** No anchors, no translations, no nav — see
the PRD for why each of those would be wrong here.

Two details that decide whether it is usable:

- **Non-`.md` targets count.** The existing pass skips anything not ending in `.md`, which is right
  for a published site. Here a link to `../../veaf-tools.spec` or `tools/klogg/veaf.conf` is exactly
  the kind of thing that rots, and one of the four defects found by hand was of that shape.
- **An ellipsis is not a link.** `CHANGELOG.md` contains `…png` inside prose, which the current
  `_LINK` regex reads as a target. Tighten it, or filter targets that cannot be paths. A gate that
  cries wolf on prose gets switched off.

Exemptions live in a **named frozenset with a comment saying why**, the way `EXEMPT` already does
for `assets/img/README.md` — not a glob. A reader must be able to see what is excluded and disagree.

## Tasks

- [x] `check_repo_links(repo_root)` returning the same `Report` shape, or a new field on it so one
      command reports both passes.
- [x] Skip `doc/` (covered), `.git`, `node_modules`, `.mypy_cache`, `.venv`, `__pycache__`.
- [x] Relative targets resolved from the containing file; existence is the whole check.
- [x] Non-`.md` targets included.
- [x] Ellipsis and other non-path targets filtered, with a test pinning the `CHANGELOG.md` case.
- [x] Exemption set, each entry commented with its reason.
- [x] Wired into `main()` so `poetry run docs-check` runs both passes and exits non-zero on either.

## Tests

- [x] **The #655 depth shift**: a file at depth 3 containing a link written for depth 4 is reported.
      This is the regression that motivated the lot; it must be impossible to reintroduce silently.
- [x] A link to an existing non-`.md` file passes; to a missing one fails.
- [x] `…png` is not reported.
- [x] An exempted file's broken links are not reported, and removing it from the set makes them
      appear — otherwise the exemption could be doing nothing.
- [x] `http://`, `https://`, `mailto:` and bare `#anchor` are all ignored.

## Acceptance criteria

- [x] Run on `develop` before tickets 02–04: reports the 92, grouped readably.
- [x] Run after them: zero.
- [x] `ruff check` and `ruff format --check` clean on the two files touched; `mypy veaf_build/` clean
      over all 20 files. The 12 pre-existing `ruff check` findings elsewhere are `test/python/`, which
      CHORE-TOOLING-GATES ticket 03 owns — not touched here.
- [x] `pytest`: 26 tests in this file, all green. **Not** "the whole tree green": one pre-existing
      failure remains in `test_convert_other_command.py`, an 8.3 short-path artefact of this
      machine's `TMPDIR` (`DPIERR~1` vs `dpierron001`), which fails with these changes stashed too.
- [ ] Coverage gate **not** bumped: measured 79.05 % against a gate of 79 %, a 0.05-point gap. The
      ratchet allows up to ~2 points, so it is already compliant, and bumping into a 0.05 margin
      would trade a satisfied policy for a red CI.
