# 05 — The bot says *tu*, everywhere

Status: ✅ done

Type: fix

## What is wrong

French has two ways of addressing somebody, and a service that uses both reads as two services.

Measured 2026-09-07, while the command descriptions of ticket 01 were being written: **29 keys
tutoient, 12 vouvoient** — and the formal ones are the most visible of the lot, because three of
them are the command descriptions themselves, which is the first thing a mission maker sees of this
bot before typing anything.

Nine of the twelve were written that same evening, by the ticket that made the forms speak French at
all. Three are older and slipped through because they carry **no `vous`**: an imperative addressed to
*vous* is formal without the pronoun — *« Corrigez-la dans ce fil »*, *« Mentionnez-moi dans ce
fil »*, *« Reposez la question »*.

## What to build

One register: **tu**. It is a squadron's Discord, not a bank, and the rest of the catalogue already
speaks that way — *« Tu as atteint ta limite »*, *« Ta demande ressemble à un ticket déjà ouvert »*.

And a test, because a rule nobody can check is a rule nobody follows. It catches both forms: the
pronoun, and the `-ez` imperative at the head of a clause — anchored on a clause boundary so `assez`
and `chez` are not read as commands. It also asserts it **can still fail**, on a sentence carrying
each form, since a pattern narrowed until it matches nothing lets the next one straight through.

## Done when

- no French string addresses the reader as *vous*, by pronoun or by imperative;
- the test states the rule, and proves it can fail;
- the module header says which register this catalogue uses, so the next string written follows it.
