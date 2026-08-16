# FIX-CTLD-LANGUAGE — a French mission with an English CTLD

Status: ✅ done — 2026-08-16

Origin: David, in game on 2026-08-16, while verifying `FIX-CTLD-NEVER-INITIALIZED`: *"CTLD est en
anglais alors que VEAF est en français — c'est pas normal"*. The CTLD radio menu had just appeared
for the first time, and it appeared in the wrong language.

## The measurement

CTLD 2 picks its language in `_activeLang()`, in this order:

1. `ctld.gs("i18n_lang")` — the mission's own `ctld-config.yaml`;
2. the module global `ctld.i18n_lang`, hard-coded to `"en"` in the engine;
3. `"en"`.

Two facts settle the fix:

- **`i18n_lang` is not in the engine's default catalogue.** Grepped `ctld.configDefault`: the key
  does not appear. A mission with no `ctld-config.yaml`, or one that never set it, therefore falls
  through to the hard-coded `"en"`.
- **Nothing on the VEAF side ever aligned it.** `i18n_lang` appears nowhere in `veaf.lua`, nor
  anywhere in the Python build.

So CTLD spoke English on every VEAF mission, whatever `mission.language` said — and nobody had seen
it before, because until `FIX-CTLD-NEVER-INITIALIZED` the CTLD menu never appeared at all.

## The fix, and why it targets the global

`veaf.ctld_alignLanguage()` writes `ctld.i18n_lang = veaf.config.language`, called from
`veaf.ctld_initialize()` **before** `ctld.initialize()` — CTLD's startup report goes through
`ctld.tr()`, so a language applied afterwards would leave that first output in the wrong one.

Targeting the **global** rather than the config setting is what keeps ADR 0016 intact: since
`_activeLang()` reads the config first and the global second, this changes the *default* and a
mission maker's explicit `i18n_lang:` in their `ctld-config.yaml` still wins.

A language CTLD has no dictionary for (`ctld.i18n[lang]` absent) is left alone and logged once:
`ctld.tr()` emits a WARNING per string it cannot resolve, so pointing the engine at an unknown
language would trade a wrong language for a flooded log.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Align CTLD's language on the mission's](tickets/01-align-language.md) | ✅ |

## A test that nearly did not run

The four Lua tests were first appended to the end of `test_veaf.lua` — **after**
`os.exit(luaunit.LuaUnit.run())`, so they never executed while reporting a green suite. Caught by
comparing the test count (346, unchanged) rather than by reading "OK". Anything appended to a luaunit
file has to go above that line.
