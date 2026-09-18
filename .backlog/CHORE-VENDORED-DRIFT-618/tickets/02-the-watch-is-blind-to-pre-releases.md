# 02 — The watch is blind to pre-releases, and says the wrong thing about it

Status: ✅ done — **David chose (c)** on 2026-09-18, with (b)'s wording as its consequence

## The finding

`VendoredChecker.latest_release` asks GitHub for `/repos/{repo}/releases/latest`, which **skips
pre-releases by design**. Every VEAF/CTLD release is a pre-release (`published-v2.0.0-rc1` … `rc8`),
so that endpoint answers 404 and the watch reports `error`.

`vendored.yaml` already anticipated the 404 and says so — *"the watch reports `unresolved` rather than
drift. Expected; do not 'fix' it by listing releases."* Two things have not held up:

1. **The status is `error`, not `unresolved`.** The weekly issue prints it under *"Errors (could not
   resolve upstream)"* with the advice *"check the repo/ref still exists"* — which sends the reader
   to look for a deleted release. `published-v2.0.0-rc7` was there the whole time.
2. **The cost is now measured.** `rc8` shipped on 2026-08-26. The vendored copy stayed on `rc7` until
   2026-09-12 — seventeen days, three weekly runs, and the watch never said a word, because the only
   thing it can see about CTLD is an endpoint that will answer 404 until a stable 2.0.0 exists. The
   artefact the watch is least able to follow is the one VEAF ships itself and updates most often.

## Options

- **(a) List releases when `/latest` 404s**, take the newest by `published_at` (or the newest matching
  a pattern), and compare that to the pin. Contradicts the note in `vendored.yaml`, which was written
  before the cost was known — the note would be replaced by this reasoning.
- **(b) Keep `/latest`, but stop calling the 404 an error.** Report `unresolved` as the file already
  claims, and word the issue so it does not send anyone hunting a deleted release. Honest, and still
  blind: a future `rc9` would go unnoticed the same way.
- **(c) Add an opt-in `prereleases: true` on the watch**, so CTLD tracks pre-releases and nothing else
  changes. Narrower than (a), no repository-wide behaviour change.
- **(d) Do nothing.** Defensible only if CTLD updates are expected to reach us through David anyway —
  which is how rc8 was found, though seventeen days late and only because a different issue was being
  investigated.

Recommendation: **(c)**, then (b)'s wording as a consequence — it fixes the artefact that actually
drifts without changing how every other watch behaves.

## Done when

Whichever option is chosen is implemented, `check-vendored` reports something true about CTLD, and
the `vendored.yaml` note agrees with the code.

## What was built

`prereleases: true` on a watch lists the releases instead of asking for `/releases/latest`. Only
CTLD's watch carries it; the seven other release watches are untouched, and a test asserts that a
plain watch still asks for stable releases only.

**A second field was needed, and the option as written would not have survived without it.** CTLD
republishes a `dev` release on every `master` build — a moving tag, a pre-release like the rest. It
was the newest release in the listing at 23:55:05 on 2026-09-16, twenty-two seconds before rc10, and
it will be the newest again after the next build that cuts no rc. Listing without a filter would
therefore have reported drift towards `dev` most weeks: the noise option (a) was rejected for, pulled
in through the back door. `tag_pattern: "^published-v"` restricts what is eligible.

Also carried out, per the decision: the error line in the recap issue now names the pre-release cause
next to *"check the repo/ref still exists"*, for any release watch that fails to resolve.

Proven against the live API rather than asserted (a check must be able to fall both ways):

```
plain /releases/latest on VEAF/CTLD : None          <- the 404 this ticket is about
listing, ^published-v              : published-v2.0.0-rc10
pinned rc10 -> up-to-date ; pinned rc9 -> drifted (latest published-v2.0.0-rc10)
```
