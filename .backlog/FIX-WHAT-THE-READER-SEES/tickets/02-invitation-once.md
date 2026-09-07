# 02 — The invitation is written once per thread

Status: ✅ done

Type: fix

## What to build

The line *"Une question complémentaire ? Mentionnez-moi dans ce fil…"* is appended to every answer
the thread carries. It is worth 146 characters, measured, and on a continuation it tells the reader
something he is in the middle of doing.

So: it goes on the answer that **opens** a thread, and not on the answers to follow-ups.

The condition is already in hand — a continuation is exactly an exchange whose context carries a
conversation — so this is a condition, not a new piece of state.

## Done when

- the first answer of a thread invites the reader to continue;
- an answer to a follow-up does not;
- an answer with no thread still promises nothing at all, as before.
