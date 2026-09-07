# 06 — *It already exists* needs a page to point at

Status: ⬜ ready

Type: fix

## What happened, in front of a human

First real `/suggest`, 2026-09-07. The bot announced:

> 📖 **La documentation semble déjà répondre à ta demande.**

and displayed, as that answer:

> *« La documentation ne décrit pas de moyen de dessiner une route pour qu'un convoi la suive. »*

The exact opposite of what it concluded. The model is instructed to answer the keyword `NOTHING`
when the documentation does not cover the subject; it answered **in prose** instead. The code sees
no keyword, infers there is an answer, and puts the question.

Sourcery had flagged the opposite risk on the same function — a prefix match loose enough to discard
a real answer. This is the other side: the model not honouring the keyword at all.

## What to build

**Require a citation.** Say *it already exists* only when the answer cites at least one
documentation page. In the case above it cited none — there was no *Pages citées* line in the
draft.

Why that criterion rather than a stricter reading of the prose: it does not depend on guessing what
a sentence means, and it matches the rule the whole service already runs on — a link the asker can
open is what lets him contradict the machine. An answer with no page to open is not an answer that
something exists.

Note what it changes: `test_an_invented_page_is_not_linked` accepts `EXISTS` with an empty link
list today, on the grounds that a title the corpus does not have is dropped. That case becomes
*silent* instead, which is the honest reading — the model named a page that does not exist.

## Definition of done

- [ ] `EXISTS` requires at least one validated page
- [ ] An answer with no citation is treated as silence, and the issue says the documentation is
      silent rather than that it answered
- [ ] The keyword path still works, decoration and all
- [ ] Unit tests: prose with no source, prose with a source, the keyword, an invented page only
- [ ] Quality gate clean
