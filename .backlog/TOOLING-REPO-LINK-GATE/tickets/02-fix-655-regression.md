# 02 — Fix the 68 links PR #655 broke

Status: ✅ done
Type: fix
Files: `.backlog/archive/*.md`, `docs/adr/0014-*.md`, `docs/adr/0015-*.md`, `docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md`

## What broke

Folding a lot's tickets into one archive file moved their content from three levels below the repo
root (`.backlog/<LOT>/tickets/01-x.md`) to two (`.backlog/archive/<LOT>.md`). Every `../` chain in a
ticket body therefore climbs one level too far. See the PRD for the full account; the shapes are:

- `../../../<path>` written from `tickets/` → needs `../../<path>` (one level **fewer**)
- `../PRD.md` → the PRD is now **in the same file**, so the link has no object
- `tickets/NN-x.md` in a PRD scope table → the ticket is now a **section of the same file**

Plus three files outside the archive that pointed at lots the sweep moved, and a handful of links
that were already wrong before the sweep (repo-root-relative paths written with no `../` at all, which
never resolved from `tickets/` either).

## Method

Scripted, not by hand — 73 links across 28 files, and hand-editing invites new mistakes.

**Candidate-based rather than rule-based**, which turned out to matter: the breakage has several
causes at once (the depth shift, links that were already wrong, cross-references between two lots that
are now both archived), so any single rewrite rule mis-fixes some of them. For each broken link, try a
short list of plausible rewrites, keep the one that **resolves**, and refuse to touch anything with
zero or more than one working candidate. Those get listed for a human instead.

That refusal is what makes the script trustworthy: 0 ambiguous cases across the whole run, so nothing
was guessed.

- [x] Candidate set: one level fewer, one level more, `../../` and `../../../` prefixes for
      root-relative paths, `<LOT>/PRD.md` → `archive/<LOT>.md`, and `.fr.md` → `.md`.
- [x] Intra-document references — `../PRD.md`, and `tickets/NN-x.md` from a PRD scope table — are
      **de-linked to plain text**, not turned into anchors. An in-file anchor would need GitHub's
      slugifier, which differs from the `pymdownx` one the gate mirrors, and ticket 01's pass
      deliberately does not validate anchors outside `doc/` — so generating them would produce links
      nothing here can verify. That is how this breakage happened in the first place.
- [x] Repoint the three `docs/` references at `../../.backlog/archive/<LOT>.md`.
- [x] Verify with ticket 01's checker, not by eye.
- [x] Read the diff of at least three archives by hand anyway — a script that rewrites 73 links
      deserves one human look at its output.

## Acceptance criteria

- [x] Zero broken links inside `.backlog/archive/`.
- [x] Zero ambiguous rewrites: every change is one the checker confirms, none is a guess.
- [x] The archives' prose is otherwise unchanged — this ticket fixes paths and de-links dead
      references, nothing else.
