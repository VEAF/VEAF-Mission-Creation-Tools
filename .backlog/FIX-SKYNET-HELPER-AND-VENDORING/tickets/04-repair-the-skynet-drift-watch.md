# 04 — Repair the Skynet drift watch, which can no longer fire

Status: ✅ done

## The watch is pointed at a file that no longer exists

`vendored.yaml`'s first Skynet watch is:

```yaml
- { kind: github-file, repo: VEAF/Skynet-IADS, ref: master,
    file: demo-missions/skynet-iads-compiled.lua, pinned: "cde577d1ac79" }
```

`poetry run check-vendored` reports it `drifted`, at `112c5442bfef2…`. That looks like the watcher
working. It is not: **`112c544` is the commit that deleted the file.** Skynet stopped committing its
build artifact when its build was redone on the CTLD model — it is `.gitignore`d there now
(`.gitignore:12`) and rebuilt by CI — so the last commit touching that path is its removal, and it
will stay the last one forever.

Measured in the Skynet repository:

```
$ git log --diff-filter=D --oneline -1 origin/master -- demo-missions/skynet-iads-compiled.lua
112c544 ci: rebuild the build on the CTLD model, release on tag
```

So the current `drifted` reading is not "3.5.0 is out". It is "the file went away", and once ticket
03 moves the pin to `112c544` to silence it, **the watch becomes permanently green and permanently
blind**. Skynet 3.6.0 would ship without this repository hearing about it — which is precisely the
failure `vendored.yaml` exists to prevent, and precisely how the vendored copy ran a month behind
before.

## What to change

- **Replace the `github-file` watch with a `github-release` one** on `VEAF/Skynet-IADS`, pinned at
  the version ticket 03 vendors. Skynet publishes a GitHub release per tag now
  (`.github/workflows/release.yml`), carrying `skynet-iads-compiled.lua` as an asset — the same
  mechanism CTLD is watched through.
- **Exclude pre-releases.** A Skynet tag that is not a plain `vX.Y.Z` is published as a pre-release
  on purpose (a release candidate must never become what anyone vendors by default). Use the same
  `tag_pattern` mechanism ticket 02 of `CHORE-VENDORED-DRIFT-618` added for CTLD's floating `dev`
  tag, so a `v3.6.0-rc1` does not read as drift.
- **Rewrite `manual_steps`.** It currently reads:

  > *"Recompile skynet-iads-compiled.lua from the VEAF/Skynet-IADS sources
  > (build-tools/build-compiled-script.ps1), run stylua on it, and re-apply the 'RP-VEAF' version
  > label."*

  All three clauses are now wrong or unnecessary. There is nothing to recompile — the release ships
  the artifact. And there is no `RP-VEAF` label to re-apply: the Regroupement and VEAF maintain
  Skynet jointly as of 3.5.0, and the version is plain `3.5.0` precisely so that the number belongs
  to neither community alone.

- **Decide what `vendoring:` should say, and measure before deciding.** It is `compiled` today,
  which described recompiling here. Taking a published asset verbatim is what `verbatim` means, and
  a `verbatim` entry needs no `manual_steps` at all. The one thing that could argue for keeping a
  manual step is the `stylua` pass: the vendored copy has been formatted, the asset is not
  necessarily. **Measure it** — diff the release asset against the current vendored file after a
  `stylua` run and without one, and pick whichever keeps the *next* sync readable. Say which, and
  why, in the PR. Do not assume: a 4 000-line formatting diff is exactly what makes the following
  bump impossible to review, which is the reason the `stylua` clause was written in the first place.

- **Leave the two `upstream-ref` watches alone.** `regroupement-patrouille/Skynet-IADS` and
  `walder/Skynet-IADS` are historical archives; the note above the entry explains why they are still
  watched, and that reasoning is unchanged.

## Also update the note above the entry

The comment block says *"VEAF therefore forked the fork, and Flogas agreed on 2026-08-31 that
VEAF/Skynet-IADS becomes the main fork"*. That is still true and still the right history to keep.
Add one line: since 2026-09-21, VEAF and the Regroupement de Patrouilles (BFR, NAWACS) maintain the
project **jointly**, in that repository. It matters here because it is the reason the version label
lost its `RP` — someone reading only the old note would try to put it back.

## Acceptance

- [x] `check-vendored` reports the Skynet entry up to date against the release, not against a commit
      touching a deleted path.
- [x] A deliberate test: the pin was moved back to `v3.4.0` and the watcher reported `drifted`
      (`v3.4.0` → `v3.5.0`), then restored. A watch that cannot fail is worth nothing, and this
      ticket exists because one was found.
- [x] A pre-release tag does not read as drift.
- [x] `test_vendored_pins_match_the_files.py` green — and **extended**: the artifact's own banner is
      now read back and compared against `pinned:`, which the test file itself invited ("adding an
      artefact here is cheap and worth doing whenever an upstream starts declaring its version").
      That check needed one repair to be correct: `WATCH_TAG_CARRIES_THE_PIN` walked *every*
      `github-release` watch, so Skynet's walder `upstream-ref` at `3.3.0` would have failed against
      a pin of `3.5.0`. `upstream-ref` watches are now skipped — they answer a different question and
      carry the ancestor's numbering.
- [x] `manual_steps` describes what someone would actually do, and the `vendoring:` value matches it.

## What the measurements said, where they differ from this ticket

**The `stylua` pass stays, and it is not close.** Diffing the 3.5.0 release asset against the copy
carried here: **9 085** changed lines as published, **843** after running it through the repo's
`stylua` config. The asset is tab-indented, the repo config is two spaces. So `vendoring:` becomes
`adapted` rather than `verbatim`, and `manual_steps` keeps a second clause — download, then format.

**`tag_pattern` is the wrong mechanism, and setting it would have caused the defect it was meant to
avoid.** In `vendored_check.py` that field is only read when `prereleases: true`; without
`prereleases`, the watch asks `/releases/latest`, which skips pre-releases by design. Skynet's
release workflow marks any tag that is not a plain `vX.Y.Z` as a pre-release (measured in
`.github/workflows/release.yml`), so a plain `github-release` watch already ignores `v3.6.0-rc1`.
Turning `prereleases: true` on — with or without a pattern — would be the one way to make an rc read
as drift. The requirement this ticket stated is met; the remedy it named is not the one used.
