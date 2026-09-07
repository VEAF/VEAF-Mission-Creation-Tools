# 04 — Say so, in both languages and in the documentation

Type: docs · Status: ✅ done

## What

Nobody discovers a mention by accident. Three places have to say it:

- **the answer itself**: the message `/ask` posts in its thread ends with one line telling the reader
  he can mention the bot in this thread to ask more. Every string goes into `texts.py`, French and
  English at parity — the parity test is what keeps the service's own default language from being the
  one that is forgotten (which is exactly the debt `FIX-SUPPORT-BOT-DEBTS` ticket 01 pays);
- **`doc/SUPPORT.md` and `doc/SUPPORT.en.md`**: the `/ask` section gains a short paragraph on
  continuing in the thread, on the fact that a follow-up spends a question of the allowance, and on
  the bot answering only in the thread it opened;
- **`CHANGELOG.md`**, one entry appended at the end of `[Unreleased]`.

## Done when

- the thread's answer tells the reader how to continue, in his language;
- both documentation pages carry it and `poetry run docs-check` passes;
- the texts parity test covers the new strings.
