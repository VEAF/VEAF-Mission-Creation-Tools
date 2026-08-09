# 03 — `veafSecurity.SecurityDisabled` was a public config field, retired as dead code

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafSecurity.lua`, `CHANGELOG.md`

## What was measured

Found on 2026-08-09 running the converted demo mission in DCS, over the bridge:

```
SecurityDisabled=true | authenticated=true | isAuthenticated()=true
```

Expected, given the mission asks for it. What was *not* expected is where that setting came
from, and that the same mission on v5 behaved the opposite way.

## The history, from the log rather than from memory

| When | `veafSecurity.isAuthenticated()` reads | Effect on a mission setting `veafSecurity.SecurityDisabled = true` |
|------|----------------------------------------|--------------------------------------------------------------------|
| before 2023-05-04 | — | — |
| `2ab20e4e` 2023-05-04 (#224) | `veafSecurity.SecurityDisabled` | works: security off, as asked |
| `8a4dd229` 2026-06-10 (#407, SECREV-009) | `veaf.SecurityDisabled` | **silently ineffective**: security stays on |

One line changed, with no alias and no warning:

```diff
-  return veafSecurity.authenticated or veafSecurity.SecurityDisabled
+  return veafSecurity.authenticated or veaf.SecurityDisabled
```

## Why it was believed to be dead

`CHANGELOG.md` records it as *"the never-assigned `veafSecurity.SecurityDisabled`"*, and
`test/lua/test_veafSecurity.lua:179` repeats the phrase. Both are true **inside this repository**
and false outside it: the field is not library state, it is a **mission-facing configuration
knob**, so the only places that assign it are mission configs — which is precisely where nobody
looked. `test/veaf-tools/demo-mission/src/scripts/missionConfig.lua:633` is one, and it is our own.

That is the lesson worth keeping, more than the fix: for a config field, "nothing in the repo
assigns it" is evidence of nothing.

## Direction of the breakage

Fail-safe, which is why three years of it went unnoticed: a mission that wanted security **off**
gets it **on**. Nobody is over-privileged. But every secured command refuses for everyone, on a
mission whose author deliberately opened them — and the failure mode is a permission denial, which
reads as "the security layer is broken", not as "your config field was retired".

`convert-v5` is **not** at fault here and needs no change: its regex accepts both spellings and
normalises to `security.disabled`, which restores the author's intent. Worth stating explicitly,
because the first reading of this bug blamed the converter.

## Tasks

- [ ] Honour `veafSecurity.SecurityDisabled` again when it is set, and **warn** that it is
      deprecated in favour of `veaf.SecurityDisabled` — the same deprecation shape ticket 02 used
      for the `L0`/`L1`/`L9` tier names, which is the precedent to copy.
- [ ] Correct the two places that assert the field is never assigned: the `CHANGELOG.md` entry for
      SECREV-009 and the comment at `test/lua/test_veafSecurity.lua:179`.
- [ ] A test for each spelling, asserting the deprecation warning fires for the old one.
- [ ] Document the field in the security page as deprecated-but-honoured, with the version that
      retires it for good.

## Acceptance criteria

- [ ] A v5-era mission config setting only the old spelling gets the security state it asked for.
- [ ] It says so in the log, once, so the mission maker can migrate rather than discover it later.
