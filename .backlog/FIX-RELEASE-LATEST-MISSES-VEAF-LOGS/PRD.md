# FIX-RELEASE-LATEST-MISSES-VEAF-LOGS — an asset published where nobody looks

Status: ✅ done — 2026-09-01

Found by David minutes after the 6.18.0 release, on the release page itself: *"pas de veaf-logs non
plus"*. He was right, and twice I said the opposite from a measurement that did not answer his
question.

## The defect

`release.yml` uploads `veaf-logs.exe` to the **versioned** release (`published-v6.18.0`) and stops
there. GitHub points every visitor at the floating `published-latest` release — that is the page the
download links in the documentation and in Discord resolve to. So the tool was published and
unreachable.

The two other assets added after the original release flow — the map-capture kit and the
cross-platform standalone binaries — both mirror onto `published-latest`, each with the same
pre-release guard. The veaf-logs step was written later and never got the same treatment.

Measured on 6.18.0:

| Release | Assets | `veaf-logs.exe` |
|---|---|---|
| `published-v6.18.0` | 10 | present, 40 256 564 bytes |
| `published-latest` | 9 | **absent** |

## Why my own checks said the opposite

Twice, and both times because the measurement did not answer the question asked:

1. **`gh release view published-v6.18.0`** listed the asset — from the *versioned* release, which was
   never in doubt. David was looking at `published-latest`. Reading the right object would have taken
   one more field.
2. On the documentation, **grepping the page for the string `6.18.0`** found it — inside the version
   *dropdown*, which lists every version ever published. It said nothing about what was served.
   Downloading `latest/` and `6.18.0/` and comparing them byte for byte is what actually settled it
   (identical, and different from `6.17.0`).

Recorded because the pattern is the same both times: a check that can only come out positive proves
nothing. The lesson is in [`verify-a-check-can-fail-both-ways`](../../CLAUDE.md).

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Mirror veaf-logs onto `published-latest`, and sweep every asset](tickets/01-mirror-veaf-logs-onto-published-latest.md) | fix | ✅ |

## Definition of done

- [x] `veaf-logs.exe` reaches `published-latest`, with the pre-release guard the other two mirrors
      carry — a release candidate must not overwrite what production users download
- [x] **A sweep, not a special case**: the test pairs *every* asset uploaded to the versioned release
      against the mirrored ones, so the next asset added cannot repeat this
- [x] A guard asserting each mirror is protected against a pre-release
- [x] The tests proven to fail on the previous workflow — 2 of the 4 do; the other two are the
      guards that check the test's own assumptions, and they held before as they do now
- [x] 6.18.0 repaired by hand: the asset was downloaded from the versioned release and uploaded to
      `published-latest`, then re-downloaded from there to prove it (HTTP 200, 40 256 564 bytes)

## Not done here

The workflow is only exercised by an actual release. This test reads it as text, which catches the
missing pairing but not a command that fails at runtime. Nothing here proves the mirror *works* —
only that it is written. The next release is what proves it, and 6.18.0's repair shows the command
itself is sound.
