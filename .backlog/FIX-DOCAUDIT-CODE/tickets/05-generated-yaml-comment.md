# 05 — The generated `mission.yaml` repeats the security lie

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `test/python/`

Found while applying `DOC-AUDIT-FIXES` 01. The shipped default
(`src/defaults/mission-folder/mission.yaml`) carried a comment claiming
`disabled: true  # true = no password required (default)`, which is backwards — the runtime default is
`veaf.SecurityDisabled = false` (`veaf.lua:29`), i.e. security **on**. That default was fixed with the
documentation.

But `lua_config_generator.py:201` emits the same misleading comment into every **generated**
`mission.yaml`, so `convert-v5` and `prepare` keep minting the wrong claim into new missions. Fixing
the shipped default alone would have left the generator as the surviving source of the lie — exactly
the shape of the defaults-lockstep rule in `CLAUDE.md` §9.7, seen from the other side.

## Fix

Correct the emitted comment; keep it short enough to stay readable in a scaffolded file. Check
whether the string is localised (the generator writes a bilingual preamble elsewhere) and fix both
locales if so.

## TDD

- Failing first: generate a `mission.yaml` and assert the security comment does **not** claim that
  the password-free state is the default. Prefer asserting the corrected wording over asserting the
  absence of the old one, so the test says what is right rather than what was wrong.

## Acceptance criteria

- [ ] Generated output and the shipped default now agree with `veaf.lua:29`.
- [ ] Test in place; full Python gate green.
