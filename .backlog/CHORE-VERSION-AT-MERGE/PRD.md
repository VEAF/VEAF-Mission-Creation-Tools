---
Status: ✅ done
---

# CHORE-VERSION-AT-MERGE — every PR fights every other PR over the same four files

## The measurement

Of the **10 merges** landed on `develop` since the 6.16.0 release (2026-08-24 evening):

| File | Merges touching it |
|---|---|
| `CHANGELOG.md` | 9 / 10 |
| `pyproject.toml` | 8 / 10 |
| `plugin/.claude-plugin/plugin.json` | 8 / 10 |
| `plugin/gemini-extension.json` | 8 / 10 |

This is not bad luck, it is the rule as written: [CLAUDE.md](../../CLAUDE.md) §9.5 requires every
change to bump the PATCH version in `pyproject.toml` and both agent manifests, and §8.7 requires a
`CHANGELOG.md` entry. **Any two PRs open at the same time therefore conflict by construction**, on
lines that carry no engineering content.

Observed cost on PR #818, a documentation-only change: **three rebases in one hour**, renumbering
6.16.5 → .6 → .7 → .8 as `develop` took each number first. Each rebase re-ran the full local gate
(~3 min) plus CI (~5 min). The change itself took less time than the merge did.

## What the numbers are worth

`6.16.0` consolidates **47 patch versions** (6.15.5 → 6.15.52); the changelog carries **52** `6.15.x`
headings. **None of those 47 was ever published** — no user could install 6.15.34. The per-PR number
is therefore a counter that looks like a version: it offers a precision the release line does not
have, and the only fact a user can act on ("which release contains this fix?") is the consolidated
one.

## The rule already contradicts itself

- [CLAUDE.md](../../CLAUDE.md) §8.7 and §9.4 say to write the entry **under `[Unreleased]`**.
- §9.5 says to **bump the PATCH version** — which is what actually happens, so `[Unreleased]` has
  not existed on `develop` since the 6.15.0 release commit.
- [.claude/commands/release.md](../../.claude/commands/release.md) Step 1 opens by reading
  "the `[Unreleased]` section of `CHANGELOG.md`", and Step 4.2 replaces that header with the version.
  **Both steps operate on a section that is not there**, and the release assistant works around it by
  hand each time.

Whatever is decided below, this contradiction has to be resolved: today three documents describe
three different processes.

## Options

### A — `[Unreleased]`, version bumped only at release *(recommended)*

PRs add their entry under a standing `## [Unreleased]` heading and **do not touch the version at
all**. `release.md` already expects exactly this and needs no change. Three of the four contended
files leave the PR diff entirely; `CHANGELOG.md` keeps a conflict surface, but between *insertions
into one section* rather than *competing headings* — and appending at the end of the section makes
most of those merge cleanly.

- Gains: the structural conflict disappears; the documented release procedure becomes true again.
- Loses: the per-PR number. Traceability moves to the PR number, already in the squash commit
  subject (`(#818)`), and to the release that ships the fix.
- To settle: the docs site stamps `pyproject.toml`'s version onto the `dev` alias
  ([`docs_version_stamp.py`](../../veaf_build/docs_version_stamp.py)). Frozen between releases, the
  dev docs would advertise the last released version instead of a number nobody can install — an
  improvement, but a visible change worth naming.

### B — keep the per-PR number, have a robot apply it after merge

A workflow on `push: develop` bumps the patch in the three manifests, renames `[Unreleased]` to the
new version, and commits. Keeps the fine-grained numbering; costs a robot commit per PR on
`develop`, needs a CI recursion guard, and still requires PRs to write under `[Unreleased]` — so it
is **A plus extra machinery**, not an alternative to it.

### C — status quo, softened

`.gitattributes` with `merge=union` on `CHANGELOG.md`. Rejected: union merges produce silently
duplicated or interleaved entries, and it does nothing for the three manifests.

## Recommendation

**A**, with B available later if the per-PR number is genuinely missed. A is the only option that
makes the three documents agree instead of adding a fourth mechanism.

## Definition of done

- `CHANGELOG.md` carries a standing `## [Unreleased]` section on `develop`.
- `CLAUDE.md` §8.7 / §9.4 / §9.5 state one process, matching `release.md`.
- A test guards it: a PR that bumps `pyproject.toml` without a matching release commit fails, or —
  simpler and closer to the real failure — `[Unreleased]` must exist on `develop`.
- `test_plugin_version.py` keeps enforcing manifest ↔ pyproject lockstep: the three still move
  together, just once per release instead of once per PR.
- The dev-docs version stamp behaves deliberately, whatever is decided in A's open point.
