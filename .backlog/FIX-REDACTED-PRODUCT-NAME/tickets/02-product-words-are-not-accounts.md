# 02 — A name the product itself uses is not an account name to redact

Status: ✅ done

Type: fix

## What is wrong

`_PLACEHOLDER_WORDS` already refuses to redact `user`, `ip`, `email` and `redacted`: names so
generic that replacing them would shred the text they are meant to protect. `veaf` belongs in that
list for the same reason, in this repository more than anywhere — it is the first word of the tool,
the scripts, the Discord, the bot and half the file names.

This is not hypothetical beyond the container. **A mission maker whose Windows account is named
`veaf`** — on a VEAF server, or on a machine set up for the association — would file a report where
every `veaf-tools` reads `<user>-tools`, and where `doctor`'s own paste block is mangled the same
way.

## What to build

Add the product's own words to the set the account-name rule refuses to act on, and say in the
comment why the list exists: not "generic words", but **words whose replacement costs more than the
name it protects**.

What must not change: the home-directory rule. `C:\Users\veaf\…` is still redacted to
`C:\Users\<user>\…` — that is a *path*, the account name is unambiguous there, and it is the rule
that catches the real leak. Only the bare-literal pass gives way.

That distinction is the whole of the ticket: a name in a path is personal data; the same letters in
`veaf-tools.exe` are the product.

## Done when

- an account named `veaf` leaves `veaf-tools` alone;
- `C:\Users\veaf\Saved Games\…` is still redacted;
- an account named `David` is still replaced everywhere, including the 56-survival case
  (`…\Temp\pytest-of-David\…`) that made the literal pass exist;
- tests for each of the three.
