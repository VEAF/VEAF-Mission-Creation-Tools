# 03 — Retrieve on the question, not on the ellipsis

Type: feat · Status: ✅ done

## What

The Worker chooses the documentation passages from the **last user turn only**. A follow-up is
almost always elliptical — David's own example, *"et si je veux créer une mission ? on a des
modèles ?"*, names neither the tools nor the subject of the thread — so retrieval against it alone
lands on the wrong pages while the model, which does hold the context, answers confidently over them.

So: build the last user turn as the **thread's opening question joined to the follow-up**, the
follow-up last and verbatim. The model reads the real conversation in the preceding turns, and reads
that turn as what it is — *here is what I asked, here is what I am asking now*.

Measured while designing this, and it settles the shape: the Worker uses the **same** last user turn
for retrieval and for the model (`latestQuery` picks it, `toGeminiContents` sends the whole list).
Separating the two would mean a new field on `/chat` and a Worker deployment; joining them costs one
string and nothing else. Rejected for the same reason: asking a model to rewrite the query would be
better in theory and spends a request of a free tier already shared with the site and the command
line.

## Done when

- the turn sent for a follow-up carries the opening question and the follow-up, in that order;
- a follow-up that is already self-contained is not made worse — the join stays bounded, and the
  follow-up is the tail;
- the joined text respects the same length ceiling as a question;
- a test asserts the shape of the turns handed to the Worker, not the wording of the answer.
