# 01 — vendor the CTLD 2 artifact and rewrite its drift-watch entry

**Status:** ⬜ ready

No dependency. Do this first: ticket 02 reads the default catalogue out of the vendored file.

## What changes

- Replace `src/scripts/community/CTLD.lua` with the `CTLD.lua` asset of the target VEAF/CTLD release
  (1.1 MB, single file, i18n dictionaries already merged in by its build). Verbatim — no VEAF edit
  of any kind, that is the point of the rewrite.
- Rewrite the `ctld` entry in [vendored.yaml](../../../vendored.yaml):
  - `source: https://github.com/VEAF/CTLD`
  - **drop `upstream`** and the `ciribob/DCS-CTLD` watch. CTLD 2 is a rewrite, not a fork: "did the
    origin ship something to port?" no longer has an answer. Say so in a comment — the file's header
    documents the two-watch convention for forks, and a reader will ask.
  - `vendoring: verbatim` (was `adapted`)
  - `manual_steps`: "re-download the `CTLD.lua` asset from the matching VEAF/CTLD release."
  - `watch:` a single `{ kind: github-release, repo: VEAF/CTLD, pinned: <tag> }`
- Update `pinned` to the human-readable shipped version.

## Watch out

`vendored_check_cli.latest_release()` calls `/repos/{repo}/releases/latest`, which the GitHub API
resolves to the latest **non-prerelease**. While VEAF/CTLD has only `-rc` tags it returns 404 →
`None` → "unresolved": no false positive, but no watch either. That is acceptable and self-correcting
once 2.0.0 ships — do **not** work around it by switching to `/releases` and taking the first entry,
which would make every rc a drift alert.

## Acceptance

- `poetry run check-vendored` runs clean and reports the `ctld` entry as unresolved (not as drift)
  while the target is a pre-release.
- No occurrence of `ciribob` remains in the `ctld` entry.

## Tests

- The vendored-drift unit tests cover an entry with a single watch and no `upstream`; add the case
  if the current suite assumes two watches for a non-`verbatim` entry.
