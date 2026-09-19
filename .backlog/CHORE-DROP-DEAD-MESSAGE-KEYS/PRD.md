# CHORE-DROP-DEAD-MESSAGE-KEYS — four messages the tools cannot print

Status: 🔄 in-progress

Opened 2026-09-19, out of [DOC-VALIDATION-MESSAGES](../DOC-VALIDATION-MESSAGES/PRD.md), which found
them by checking each of the 98 `validate.*` / `builder.*` messages against the code that emits it —
the check had to happen anyway, to avoid documenting a message nobody can receive.

## What they are

| Key | Why it cannot be printed |
|---|---|
| `builder.declared_group_missing` | Referenced nowhere. The build reports that situation through `validate.missing_group` |
| `builder.orphan_lua_module` | Referenced nowhere. Its twin `builder.orphan_pipeline_file` *is* emitted |
| `builder.injecting_scripts` | Referenced nowhere. A progress line |
| `builder.mandatory_community_kept` | Referenced, but behind `if script_id in MANDATORY_COMMUNITY_SCRIPTS`, and that `frozenset` is **empty** |

The first three are dead weight in both locale files. The fourth is a whole branch.

## The fourth was kept on purpose, and is being deleted anyway

`MANDATORY_COMMUNITY_SCRIPTS` carries a comment saying so: *"Kept rather than deleted because the
mechanism below is the answer to 'this dependency must be injected whatever the mission says', which
is a thing that will be true again."* It was emptied when MiST became opt-in (`DROP-MIST`).

David asked for it to go, after being told the branch existed and what it did. Two things make that
the right call rather than merely an instructed one:

- **It is speculative, and the repository forbids that** — CLAUDE.md rule №2, "do not add any
  speculative features or abstractions". A mechanism kept for a need that *will be true again* is
  exactly that.
- **The real case is already covered.** A mission whose own scripts call MiST gets it injected
  anyway, announced by `builder.mist_injected_for_custom_scripts` — the live message that does the
  job this dead one was keeping a seat for.

It is about ten lines, and `git` has them if the need returns.

## Its comment was also wrong

The branch's inner comment still reads *"MiST is a hard dependency of the VEAF scripts — always
inject it"*, which stopped being true at `DROP-MIST`. It has been contradicting the empty set beside
it ever since. Deleting the branch removes the contradiction with it.

## Not done: a test that catches the next dead key

Tempting, and measured before rejecting: **64 of the 1118 locale keys** match no literal string in
the source. Nearly all are false positives — `tree.*`, `pipeline.*`, `generated.*` and `cmd.*` are
built dynamically (`t(f"tree.group.{self.id}.label")`), so a naive guard would fail on 64 keys of
which 4 are real. A useful version would have to resolve those f-strings, which is a different and
much larger job than this one.

## Definition of done

- [ ] The four keys gone from **both** locale files, which stay in step
- [ ] The dead branch, its constant and its stale comment gone
- [ ] `poetry run pytest`, ruff check + format, mypy clean
