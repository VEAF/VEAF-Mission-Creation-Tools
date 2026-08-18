# FIX-BUILD-YAML-TRUNCATION — the build deletes whatever sits after the build marker

Status: ⬜ ready

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

## Definition of done

- [ ] A section after `build:` survives a build with `--dev-mode`
- [ ] The docstring's promise becomes true, or it stops promising it
- [ ] A test that writes a section after `build:` and asserts it survives
- [ ] The round-trip question above answered in writing, whatever the answer
