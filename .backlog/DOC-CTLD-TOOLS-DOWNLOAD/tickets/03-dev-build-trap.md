# 03 — "The most recent one is at the top" points at a build that is not a release

Status: ✅ done

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`

## Found while re-verifying the lot, not by a report

Closing the lot meant re-checking its premises against `VEAF/CTLD` rather than trusting the
2026-08-25 measurement. Measured **2026-09-01**:

| Claim | Verdict |
|---|---|
| `ctld-tools.exe` is a release asset | holds — 22.5 MB, attached to `published-v2.0.0-rc8` |
| Every CTLD 2 release is a pre-release | holds — all 9 are, and `GET /releases/latest` answers **404** |
| A "CTLD dev build" release exists | holds — tag `dev`, rebuilt 2026-08-26, carries `ctld-tools.exe` |

The download block was written against that list, and one sentence in it does not survive the
check: *"The most recent one is at the top of the list."*

The `dev` tag is a **rolling** release. Its own body says so — *"This is not a release. It is the
tool built from the latest merge into `develop`"* — and it returns to the top of the list every
time it is rebuilt. On 2026-08-26 it missed the top spot by three minutes, purely by accident of
publishing order. Telling a reader to take the top entry therefore points them, sooner or later, at
a build carrying no version number, immediately after telling them to match the version.

## What ships

The warning admonition loses that sentence and gains the discriminator: the `CTLD dev build` entry
is not a release, real releases are tagged `published-v…`, and the version rule below the
admonition is what picks among them.

Nothing else in the block changes — the anchor, the prerequisites row and the version-reading
instruction all still hold.

## Definition of done

- [x] Neither language tells the reader to take the top entry
- [x] The `CTLD dev build` entry is named, and said not to be a release
- [x] `poetry run docs-check` green
