# TOOLING-REPO-LINK-GATE — the link gate stops at `doc/`, and the repo rotted behind it

Status: ✅ done

> **Tickets 01, 02, 03 and 05 delivered 2026-08-05**: the pass exists, the 92 links are fixed, CI
> triggers on the paths it checks. The lot stays open on **ticket 04** alone — whether the three
> historical documents should be exempted for good, repaired, or deleted. They are exempted in the
> meantime so the gate is green.

## Problem

`docs-check` guards the **published** documentation: `check_docs(doc_dir, mkdocs_yml)` walks
`doc/` and applies six rules. Everything else in the repo — `.backlog/`, `docs/adr/`,
`docs/exploration/`, `docs/agents/`, the root `*.md` — is unguarded. It has 340 markdown files
and 555 relative links, none of them checked.

Measured 2026-08-05: **92 of those links are broken.**

The trigger was noticing three dangling links while filing the dcs-sms lots. Three turned out to
be 92, and **68 of the 92 are a regression from PR #655**, the archive sweep — which makes this a
gate that would have caught its own absence.

## How #655 broke 68 links, and why "lossless" did not catch it

The sweep folded each lot's tickets into a single archive file. A ticket lived at
`.backlog/<LOT>/tickets/01-x.md`, **three levels below the repo root**. The archive is
`.backlog/archive/<LOT>.md`, **two levels below**. So every `../` chain in a ticket body now climbs
one level too far:

| In the ticket, correct | In the archive |
|---|---|
| `../../../docs/adr/0010-….md` | climbs above the repo — needs `../../docs/adr/0010-….md` |
| `../PRD.md` | the PRD is now **in the same file** — the link has no object at all |
| `tickets/01-x.md` (from the PRD's scope table) | the ticket is now a **section of the same file** |

The PRD's own outward links are fine: `.backlog/<LOT>/PRD.md` sat two levels below the root, exactly
where the archive sits, so nothing shifted for them.

The verification that ran was line-level: every non-blank line of all 258 source files was
confirmed present in its archive, 0 losses. That was true and it was not enough — **line fidelity
is not link validity**, and a relative path is a fact about where a file sits, not about its
content. Three more casualties sit outside the archive, in `docs/adr/0014`, `docs/adr/0015` and
`docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md`, which point at lots that moved.

## The 92, by what they need

| Category | Count | Nature |
|---|---|---|
| The #655 archive fold (depth shift + `../PRD.md`) | 65 | mechanical, scripted |
| References to lots archived by #655, from `docs/` | 3 | mechanical |
| `doc/*.fr.md` links in `README.md` / `CONTRIBUTING.md` | 11 | mechanical — the convention is `X.md` (French) + `X.en.md`, so `.fr.md` never existed |
| Historical documents: `docs/superpowers/` plans and specs, `CODE_DOC_REVIEW_2026-07-01.md` | 11 | **judgement** — see below |
| `…png` in `CHANGELOG.md` | 2 | a false positive: an ellipsis in prose, not a link |

## The historical documents are a real design question, not a chore

`docs/superpowers/plans/2026-06-24-backlog-restructure.md` links to `backlog.md`,
`CLEANUP-LUPA/PRD.md`, `RELEASE/PRD.md`, `archive/`. Those were **correct when it was written**:
it is a design document describing the flat `backlog.md` era, from before the restructure it
proposed. `CODE_DOC_REVIEW_2026-07-01.md` is the same shape — a dated review whose links were
relative to `doc/`.

"Fixing" them would rewrite a record of a past state into something that never existed. Exempting
them says the gate does not police history. Deleting them says the record has served its purpose.
All three are defensible and it is not the gate's call to make — ticket 04 puts the question to
David rather than guessing, and the gate ships with them exempted so it can be green in the
meantime.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Repo-wide relative-link pass in `docs_check`](tickets/01-repo-link-pass.md) | ⬜ |
| 02 | [Fix the 68 links PR #655 broke](tickets/02-fix-655-regression.md) | ⬜ |
| 03 | [Fix the `.fr.md` links](tickets/03-fix-fr-md-links.md) | ⬜ |
| 04 | [Decide what to do with the historical documents](tickets/04-historical-documents.md) | ⬜ |
| 05 | [Wire the pass into CI](tickets/05-ci-wiring.md) | ⬜ |

## What this pass does not check, deliberately

- **Anchors.** In `doc/` they are checked against `pymdownx.slugify`, which is what mkdocs uses.
  Outside `doc/` the renderer is **GitHub**, whose slugifier differs. Claiming to validate those
  anchors would produce confident false positives, which is how a gate loses its authority.
- **Translations and nav.** Meaningless outside the published site: a ticket has no English twin
  and belongs in no menu.
- **External URLs.** Out of scope here as they are in the existing pass — a network-dependent gate
  is a flaky gate.

## Definition of Done

- The new pass reports zero defects on `develop`, with the exempted historical documents listed
  explicitly in code rather than silently skipped by a glob.
- Its tests cover the depth-shift case that #655 produced, so this exact regression cannot recur.
- CI runs it. A gate nobody runs is the situation this lot exists to end.
- `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet;
  version bumped in `pyproject.toml` **and** `plugin/.claude-plugin/plugin.json`.
