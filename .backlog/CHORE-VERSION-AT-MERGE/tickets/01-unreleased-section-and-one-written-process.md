---
Status: ✅ done
---

# 01 — Restore `[Unreleased]` and make the three documents say one thing

Assumes option **A** of the PRD is chosen.

## Do

1. `CHANGELOG.md`: add a standing `## [Unreleased]` section above the newest version heading.
   New entries go **at the end** of that section, not the top — appending conflicts far less
   than prepending when two PRs land together.
2. `CLAUDE.md`: §8 step 7 and §9 step 4 keep "write under `[Unreleased]`"; **§9 step 5 loses the
   PATCH bump** and instead states that the version moves only in a release commit, with both
   agent manifests, and that `test_plugin_version.py` still enforces their lockstep.
3. `.claude/commands/release.md`: Step 4.2 already replaces the `[Unreleased]` header — verify it
   reads correctly now that the section genuinely exists, and add the two manifests to Step 4.3
   (today it names only `pyproject.toml`, while Step 5.2 does list the plugin manifest).

## Done when

A PR touching only source code has a diff free of `pyproject.toml` and both manifests, and the
release assistant's Step 1 finds the section it looks for.
