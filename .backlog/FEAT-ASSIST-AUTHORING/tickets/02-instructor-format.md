# 02 — the instructor format: `control`, enriched in place

**Status:** ⬜ ready — depends on 01.

Two fields on a step, and everything else about the checklist format is unchanged.

| Field | Written by | Meaning |
|---|---|---|
| `control` | the instructor | free text naming a cockpit control and its wanted position |
| `resolved_from` | the resolver | the `control` text the technical fields were derived from |

`resolved_from` is the whole synchronisation mechanism. A step is **stale** when `control` is set and
`resolved_from` is absent or different; the resolver touches those and leaves the rest alone. No
timestamps, no hashes, no second file — the instructor can read the state of their own checklist.

A step may of course still be written the technical way, with no `control` at all: that is what the
shipped F-16C checklist is, and it must keep loading untouched.

## Rules

- `control` alone is valid and means "not resolved yet": the build **fails** with a message naming
  the step, because a checklist with an unresolved step would silently never validate it.
- `control` + technical fields + matching `resolved_from` is a resolved step; the build ignores
  `control` entirely from then on. It is documentation and a re-resolution key, nothing else.
- `resolved_from` without `control` is a leftover from someone deleting the source text; warn, do not
  fail — the technical fields are still valid.

## Tests

`test_checklist_format.py`: the three states above; a stale step is detected; the shipped checklist
(no `control` anywhere) is unaffected; `control` never reaches the emitted Lua, since the engine has
no use for it.

## Definition of done

- Model, validation and the staleness predicate, exposed for ticket 03 to drive.
- The emitted Lua is byte-identical for a checklist that carries no `control`.
