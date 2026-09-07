# 01 — The forms speak the user's language

Status: ⬜ ready

Type: fix

## What is wrong

The service translates everything it **says** — `texts.py` holds a French and an English catalogue at
parity, and a test fails when they drift. It translates nothing it **shows**. Measured 2026-09-07,
in `discord_bot.py`:

| Hard-coded in English | Count |
|---|---|
| Modal titles (`Report a bug`, `Suggest an improvement`) | 2 |
| Field labels across both modals | 11 |
| Placeholder text | 1 |
| Command descriptions, as Discord's picker shows them | 3 |

French is the service's **default** language, and its most visible surface is English-only. David
switched his client to French to check and nothing moved, which is how this was found: the first
time somebody used the bot who had not written it.

## What to build

The modal is constructed **when the command is typed**, so the interaction — and its locale — are in
hand. Pass the language to the constructor and pull every label from `texts.py`, like the rest.

- `BugModal` and `SuggestModal` take a `lang`, defaulting to the service's default.
- The eleven labels, two titles and one placeholder become catalogue entries. `test_texts.py`
  already fails on a key present in one language and missing in the other, so parity is enforced
  the moment they move there.
- Command **descriptions** are set at registration, once, before any interaction exists. They cannot
  follow a user's locale without `discord.py`'s translator machinery — see the open question.

## The one thing that must not change

The **values** of the component menu. They are the options of
`.github/ISSUE_TEMPLATE/feature_request.yml` and `bug_report.yml`, word for word, and
`tests/test_suggestion.py` asserts they still exist in those files. A translated value is a component
nobody can filter on.

Discord separates a choice's *displayed name* from its *value*, so a French label over an English
value is possible — but the names of choices are declared at registration, like the descriptions.

## Decided: the translator is in scope

The question was whether to adopt `app_commands.Translator` — the only way to localise command
descriptions and choice names, and a machinery of its own (a class, a locale table, a registration
hook) that the modals do not need.

**Decided 2026-09-07 by David, with a screenshot of the command picker:**

```
/ask      Ask a question about the VEAF Mission Creation Tools documentation
/bug      Report a bug — a short form, and the files you have
/suggest  Suggest an improvement — checked against what already exists
```

That is the first thing any mission maker sees of this bot, before typing anything, and it is the
one surface a per-interaction fix cannot reach: descriptions are registered once, before any
interaction exists. So the translator is in scope, and this ticket has two halves:

1. **the modals** — titles, labels, placeholders — from `texts.py`, using the locale of the
   interaction that opened them;
2. **the registered surface** — the three command descriptions, and the component choice *names* —
   through `app_commands.Translator`, whose table Discord stores and serves per client language.

The second half is also what makes a French label possible over an English component **value**,
which must stay word for word the issue templates' own.

## Definition of done

- [ ] Modal titles, field labels and placeholders come from `texts.py`, in both languages
- [ ] The language comes from the interaction, not from a constant
- [ ] Component **values** unchanged, and the tests asserting they match the templates still pass
- [ ] Command descriptions and choice names localised through `app_commands.Translator`
- [ ] Discord's picker shows French to a French client, verified in the client and not only in a test
- [ ] Unit tests: a modal built for `fr` and one for `en` carry different labels
- [ ] Quality gate clean
