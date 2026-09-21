# 04 — Repair the Skynet drift watch, which can no longer fire

Status: ⬜ ready

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

- [ ] `check-vendored` reports the Skynet entry up to date against the release, not against a commit
      touching a deleted path.
- [ ] A deliberate test: point the pin one release back and confirm the watcher reports `drifted`.
      A watch that cannot fail is worth nothing, and this ticket exists because one was found.
- [ ] A pre-release tag does not read as drift.
- [ ] `test_vendored_pins_match_the_files.py` green.
- [ ] `manual_steps` describes what someone would actually do, and the `vendoring:` value matches it.
