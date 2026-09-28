# FIX-BUILD-YAML-TRUNCATION — the build deletes whatever sits after the build marker

Status: ✅ done — 2026-08-19, both tickets · archived 2026-09-28

Origin: found on 2026-08-17 while preparing the #290 verification mission. A `security:` block kept
vanishing from `mission.yaml`; David flagged it three times before the cause turned out to be the
build itself and not the author.

## The defect

`veaf_tools/helpers.py:240-246`, in `_update_build_config_in_yaml`:

```python
idx = content.find("\n" + _BUILD_CONFIG_MARKER)
if idx >= 0:
    content = content[:idx]          # everything after the marker is discarded
content = content.rstrip("\n") + "\n" + new_section
yaml_path.write_text(content, encoding="utf-8")
```

Called whenever `build` runs with `--dev-mode` or `--scripts-path` (`commands/build.py:271`). It
persists the `build:` section by **truncating the file at the marker** and rewriting the tail.

Its own docstring says *"Uses a text-based replacement so all other comments in the file are
preserved."* That is true for everything **before** the marker and false for everything after it.

## Who it hurts

Any mission maker who builds with `--dev-mode` — the documented dev workflow. The `build:` section is
appended at the end, so the first build is harmless; **the damage starts the moment anything is added
after it**, which is the natural thing to do when the file already ends with `build:`. The next build
eats it, silently, and `mission.yaml` is the file that decides how the mission behaves.

Measured on the verification mission: the `security:` block was written, the build ran, and the block
was gone — three times, because it went back in the same place each time.

## Scope

Replace the truncate-and-append with an operation that **cannot lose content**. Two candidates, and the
lot should say which and why:

- **Bounded replacement** — find the marker *and the end of the `build:` block* (first line at
  indentation 0 that is neither blank nor a comment), replace only that span. Keeps the text-based
  approach and its comment preservation.
- **Load / mutate / dump** — read the YAML, set `build`, write it back. Loses hand-written comments,
  which is why the text approach was chosen in the first place; probably not acceptable here, and worth
  stating rather than leaving implied.

The first looks right. Whichever wins, the test is the same and it is the one that was missing: write a
`mission.yaml` with a section **after** `build:`, run the persistence, and assert that section is still
there.

## The question this lot should answer beyond itself

**Three defects of the same family surfaced on 2026-08-17 alone** — code that writes without looking at
what it destroys:

| Where | What it destroyed |
|-------|-------------------|
| `warehouses_bootstrap` (`FIX-WAREHOUSES-LIST-FORM`) | the mission's own airfields, their coalitions and stock |
| `coalition_placeholder` (`FIX-GROUP-CONTAINER-SHAPE`) | nothing — it crashed instead, which is the lucky version |
| this one | any `mission.yaml` content after the build marker |

All three are silent, and all three were found by accident rather than by a test. So: **is there a
check that a writer preserves what it did not mean to change?** A round-trip assertion — read, write
without mutating, compare — would have caught the first and the third. Answer it here; if the answer is
a shared test helper, that is worth more than this one fix.

## The question, answered — 2026-08-19

**Yes, and the check belongs to the writer rather than to the defect.** `assert_round_trip_identical`
asks one question — *invoked with nothing to change, do you reproduce your input byte for byte?* — and
`assert_preserved` covers the case where one section legitimately moves. Both live in
`test/python/testlib/writer_preservation.py`, next to the other shared test machinery.

It is not a theoretical win. **The identity check found a second defect in this very writer on its
first two uses**, and it is of exactly the family this lot is about: `write_text` with no `newline`
lets Python translate every `\n` to `os.linesep`, so on Windows a call meant to touch one section
came back with **every line of the file changed**. Measured: an LF fixture of 11 lines returned as 11
CRLF lines. `mission_yaml_editor.save_yaml` — which the MCP composites use — had the same
construction and the same result. Both now write `newline="\n"`; every `mission.yaml` in this
repository is LF.

So of the three defects tabled above, the round-trip would have caught two, and it immediately caught
a fourth nobody had reported. What it cannot catch is `coalition_placeholder`, which raises rather
than destroys — the lucky version, and `FIX-GROUP-CONTAINER-SHAPE`'s to answer.

**Deliberately not done here:** sweeping every writer in the repository with the identity check. That
is a lot of its own; the helper existing is what makes it cheap rather than open-ended.

## Definition of done

- [x] A section after `build:` survives a build with `--dev-mode`
- [x] The docstring's promise becomes true, or it stops promising it
- [x] A test that writes a section after `build:` and asserts it survives
- [x] The round-trip question above answered in writing, whatever the answer

---

## Tickets, in full

## 01 — Replace the truncate-at-marker with a bounded replacement

Status: ✅ done — 2026-08-19. Bounded replacement shipped (`_build_section_span`), and the
reproduction is the test fixture. The malformed shape mattered: a marker with no `build:` key under it,
where consuming "the indented block" would have swallowed the next section — the original defect wearing
a different hat.
Type: fix
Files: `src/python/veaf-tools/veaf_tools/helpers.py` (`_update_build_config_in_yaml`), tests

### The defect, reproduced 2026-08-19

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

### What ships

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

### Done when

- A section after `build:` survives, asserted on the real reproduction above and not a synthetic one
- A `build:` block at the end of the file still round-trips to the same bytes
- A marker with no `build:` key does not eat the section after it
- The docstring's promise is true, or it stops promising it
- Blank lines do not accumulate across repeated calls

---

## 02 — Answer the round-trip question with a shared helper

Status: ✅ done — 2026-08-19. `test/python/testlib/writer_preservation.py` ships both helpers,
and the identity one **earned itself on its first two uses** by finding a second defect in the same
writer — see the PRD.
Type: chore
Files: `test/python/testlib/` (a new shared helper), the tests of the writers named below

### The question this answers

The PRD asks it in writing: **is there a check that a writer preserves what it did not mean to
change?** Three defects of that family surfaced on 2026-08-17 alone, all silent, all found by accident:

| Where | What it destroyed | Would a round-trip have caught it? |
|---|---|---|
| `warehouses_bootstrap` (`FIX-WAREHOUSES-LIST-FORM`) | the mission's own airfields, coalitions and stock | **yes** |
| `coalition_placeholder` (`FIX-GROUP-CONTAINER-SHAPE`) | nothing — it crashed, the lucky version | no (it raises) |
| `_update_build_config_in_yaml` (ticket 01) | any `mission.yaml` content after the build marker | **yes** |

Two of three. That is the answer, and it is worth more than either fix: the check is not per-defect, it
is per-writer, and every writer in this repository can be asked the same question.

### What ships

Two helpers in `test/python/testlib/`, which `pyproject.toml` already puts on the test path as the home
for shared test machinery:

- **`assert_round_trip_identical(path, writer)`** — read the file, invoke `writer` with **no intended
  change**, compare **bytes**. A writer that cannot reproduce its own input is a writer that is
  destroying something, whatever it thinks it is doing. On failure, a unified diff naming the lost
  lines, because "files differ" sends the reader back to where these three defects were found.
- **`assert_preserved(path, mutate, *needles)`** — for the intentional mutation: run `mutate`, then
  assert each needle is still in the file. Weaker than identity and necessary alongside it, since a
  writer that *must* change one section still has to leave the rest alone.

Applied here to `_update_build_config_in_yaml`. `FIX-GROUP-CONTAINER-SHAPE` uses the same helper for
its own "a mission nobody touched builds byte-identically" requirement, which is why this ticket lands
first.

### Deliberately not in scope

Sweeping every writer in the repository with the identity check. That is a lot of its own, and it would
turn a bounded fix into an open-ended audit — the helper existing is what makes that lot cheap later.
Say so here rather than leave it implied.

### Done when

- Both helpers exist in `test/python/testlib/`, with docstrings saying what each one catches
- `_update_build_config_in_yaml` is covered by both
- A failure message names the lost lines, not merely that the files differ
- The answer to the PRD's question is written into the PRD itself

---
