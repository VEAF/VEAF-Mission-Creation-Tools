# Lot SECREV-2 — act on the 2026-07-01 security review, finding by finding

Status: ✅ done — **all 140 findings decided**, 2026-08-11.

Source: `CODE_DOC_REVIEW_2026-07-01.md` — 2 606 lines, 140 findings, produced by 20 reviewers with an
adversarial verifier that re-read each security/bug finding and **refuted 6**, which were dropped.

> **Nothing in this review was ever tracked.** It sat at the repository root for a month. The archived
> `SECREV` lot is a *different* thing — it closed an RCE in the Python `luadata` parser.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Currency triage — method, tooling, and the eight verified | ✅ |
| 02 | Untrusted text into executed code — the five layers | ✅ |
| 03 | Security gates that fail open | ✅ |
| 04 | Integrity checks that pass when metadata is missing | ✅ |
| 05 | The two high-severity correctness bugs | ✅ |
| 06 | The 24 medium findings | ✅ |
| 07 | The 108 low and info findings | ✅ |

## Outcome

| Outcome | |
|---|---:|
| fixed | 95 |
| already-fixed | 9 |
| decided-deferred | 21 |
| confirmed-open | 8 |
| does-not-reproduce | 5 |
| wontfix | 2 |

The 8 `confirmed-open` are the shared-password family David ruled on, tracked in
[`REVIEW-SECURITY-LAYER`](REVIEW-SECURITY-LAYER.md). The 21 deferred are cosmetic findings reserved for
files being changed anyway, each listed by file in ticket 07 so they resurface when a lot edits one.

**Both criticals are closed in production, not only in the repository** — David deployed the server hook
on 2026-08-11.

## What the review got wrong, which is the reusable part

The triage checked every finding for currency rather than taking it on trust, and that repeatedly paid:

- **Six findings under-reported their own scope.** VMR-008 reported *one* English page linking to a
  French one; measured across the tree, **239 links on 38 `.en.md` pages**. And `docs_check` already
  knew about the situation — it **followed the twin** to check anchors — thereby compensating for the
  mistake in silence instead of reporting it. *A checker that quietly works around a defect is worse
  than one that ignores it, because it makes the defect invisible.*
- **Some were mislabelled.** VMR-091 silently drops data and VMR-074 is a crash, both filed as low.
- **Some dissolved on measurement.** The shared-password dilemma I put to David — break every server or
  merely document the weakness — had **both premises wrong**: `password_MM` was always *replaced* by the
  generator while `password_L1` was only *extended*, three lines apart in the same function. So
  declaring your own passwords **widened** the accepted set. The fix was neither destructive nor
  cosmetic: clear before adding, as Mission Master already did.
- **The documentation said SHA-256 while the code hashes SHA-1** — in `mission.yaml`, the generator
  template, the MCP docstring and both GUIDE pages. A mission maker following the docs produced a hash
  that can never match, believing access was restricted while only the public default still worked. And
  `MISSION_YAML_REFERENCE` *already* carried a "SHA-1, not SHA-256" warning: the repo had caught this in
  one place and left it wrong in five others.
- **One finding inverted its own severity.** VMR-136, filed *Readability*:
  `string.format("Keyword password", val)` has no format specifier, so `val` was discarded. A **working**
  `%s` would have written a marker password into the log — the broken format was what prevented it.
  Fixing it as reported would have turned a cosmetic finding into a security one.

## Decisions worth keeping

- **VMR-083 / VMR-088 wontfix, measured first.** `veaf.serialize` has three call sites, all debug
  traces, and nothing reloads its output as Lua — the finding's entire argument. And the site VMR-088
  names is one of **794** pre-formatted trace calls in `src/scripts/veaf/`: that is a lot, not a finding.
- **SHA-256 support proposed, then withdrawn on cost.** There is no SHA-256 implementation anywhere in
  the Lua tree and Lua 5.1 has no bitwise operators — ~200 lines of hand-written crypto in pure
  arithmetic. Not the modest addition I had sold it as.
- **`veafRemote`'s SLMOD remains deleted** (VMR-130): a `mist.utils.dostring` of arbitrary Lua behind a
  password that ships in a public repository, whose registration API had been gone since August 2021.
  Four years of a loaded gun with no trigger attached.
