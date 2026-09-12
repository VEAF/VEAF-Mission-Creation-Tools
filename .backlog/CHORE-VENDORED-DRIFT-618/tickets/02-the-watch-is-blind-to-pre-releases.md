# 02 — The watch is blind to pre-releases, and says the wrong thing about it

Status: ⬜ ready — **needs David's decision**, because it changes what the weekly issue reports

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
