# 03 — More than one role may open the hypothesis

Status: ✅ done

Type: feat

## What is wrong

`SUPPORT_BOT_ENRICH_ROLE_ID` reads **one** role id. The decision it encodes — which role means
"VEAF member" — belongs to the association, and the association may well answer with two: *mission
maker* and, say, *staff*.

Recorded as a debt when lot 4 shipped: ten lines in `enrichment.py` and `config.py`.

## What to build

Accept a list where one value is accepted today, and keep the single value working: a deployment
that has one role must not have to learn a syntax.

- Comma-separated ids, whitespace tolerated.
- **Every id still validated as numeric**, with the same refusal at startup. That check exists
  because a mention (`<@&123…>`) or a role *name* compares unequal to every id the bot will ever
  see: the hypothesis would be refused for everybody, for ever, while each issue politely explained
  it is a members' extra — a configuration mistake behaving like a working feature.
- Empty still switches the hypothesis off entirely, which is the default.

## Definition of done

- [ ] One id, several ids, and empty all behave as documented
- [ ] A malformed id in a list is refused at startup, naming its shape and not its value
- [ ] `.env.example` and the README updated together
- [ ] Unit tests: one role, two roles, a member holding neither, a malformed entry
- [ ] Quality gate clean
