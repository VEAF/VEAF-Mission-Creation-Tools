# 04 — Say what the bot is, and what it is not

Status: ⬜ ready

Type: docs

## What to write

Two audiences, two documents.

**For users**, on the support page created in
[`FEAT-SUPPORT-DIAGNOSTIC` ticket 03](../../FEAT-SUPPORT-DIAGNOSTIC/tickets/03-doc-support-page.md):
what `/ask` does, where it answers, that the answer comes from the documentation and may be wrong,
that a thread is public, and what to do when the bot does not know. Both languages, in the `nav`.

**For operators**, next to the service: how to run it, which environment variables it needs, how to
register the Discord application and which permissions it requires, what the quotas are set to and
where to change them, and how to tell whether it is alive.

## The line to hold

The bot answers **from the documentation**. Say it plainly, including the consequence: a
documentation gap becomes a wrong or missing answer, and the fix is to write the page, not to
retrain anything. That framing is what keeps `/ask` honest and turns its failures into documentation
tickets.

Also say what it deliberately does not do in this lot: it does not read the sources, it does not
open issues, it does not analyse logs. Each of those arrives later, and users who expect them now
will read the silence as a bug.

## Notes

- Explicit English anchors on anything cross-linked; both languages in lockstep.
- No hand-written version numbers.
- `poetry run docs-check` is the gate.

## Definition of done

- [ ] User-facing section on the support page, both languages, in the `nav`
- [ ] Operator documentation next to the service: variables, Discord registration, permissions,
      quotas, liveness
- [ ] The "answers from the documentation" limit stated explicitly, with its consequence
- [ ] What the bot does not do yet, stated
- [ ] `poetry run docs-check` passes
