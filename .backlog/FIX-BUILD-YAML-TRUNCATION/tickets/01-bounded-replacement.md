# 01 — Replace the truncate-at-marker with a bounded replacement

Status: ✅ done — 2026-08-19. Bounded replacement shipped (`_build_section_span`), and the
reproduction is the test fixture. The malformed shape mattered: a marker with no `build:` key under it,
where consuming "the indented block" would have swallowed the next section — the original defect wearing
a different hat.
Type: fix
Files: `src/python/veaf-tools/veaf_tools/helpers.py` (`_update_build_config_in_yaml`), tests

## The defect, reproduced 2026-08-19

A `mission.yaml` holding a `security:` block **after** the build marker, then one
`_update_build_config_in_yaml(dev_mode=True)`:

| Content | Survived |
|---|---|
| `security:` | **no** |
| `password_hashes` | **no** |
| the hash itself | **no** |
| the maker's trailing comment | **no** |

`content = content[:idx]` discards everything from the marker onward and the tail is rewritten from
the `build:` template alone. The docstring promises *"all other comments in the file are preserved"* —
true before the marker, false after it.

## What ships

The **bounded replacement** the PRD favours, for the reason it gives: the text-based approach is what
preserves comments, and a load/mutate/dump would lose every one of them.

The span to replace runs from the marker's own line (with the blank line before it, so blanks do not
accumulate) to the end of the `build:` block — the first line after `build:` that is neither blank nor
indented. That rule stops at a following section's comment header (`# ── Security ───` sits at column
0), which is exactly what has to be preserved.

Two shapes to get right rather than assume:

- **A marker with no `build:` key under it** (a maker deleted the key, kept the header). Replacing to
  "the end of the indented block" would consume the next section. Only the comment run is replaced.
- **A `build:` block at the end of the file**, today's nominal case. The output must be what it is
  now, so an untouched project sees no diff.

## Done when

- A section after `build:` survives, asserted on the real reproduction above and not a synthetic one
- A `build:` block at the end of the file still round-trips to the same bytes
- A marker with no `build:` key does not eat the section after it
- The docstring's promise is true, or it stops promising it
- Blank lines do not accumulate across repeated calls
