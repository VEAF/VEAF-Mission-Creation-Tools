# 03 — Fix the `.fr.md` links

Status: ✅ done
Type: fix
Files: `README.md`, `CONTRIBUTING.md`

## What is wrong

Eleven links point at `doc/<something>.fr.md`. **That suffix has never existed here**: the convention
is `X.md` for French and `X.en.md` for English — `docs_check._twin` encodes exactly that, and
`mkdocs-static-i18n` is configured for it.

So these are not stale links to moved files; they are links to files that were never created. They
have been broken since they were written, on the repo's two most-read pages, and nothing looked.

## Tasks

- [x] Repoint each `doc/X.fr.md` to `doc/X.md`.
- [x] Check the English counterparts on the same lines while there: if a page links FR and EN side by
      side, the EN one should be `X.en.md` and may be wrong too.
- [x] Confirm each target exists after the change — some may have moved for unrelated reasons, in
      which case the fix is a different path, not a mechanical suffix swap.

## Acceptance criteria

- [x] Zero broken links in `README.md` and `CONTRIBUTING.md`.
- [x] Every repointed target verified to exist.
