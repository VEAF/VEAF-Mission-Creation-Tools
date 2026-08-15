# 01 — Tier names: the dispatchers refuse the decided vocabulary

Status: ✅ done — both dispatchers speak both vocabularies; VEAF's own 24 declarations migrated to the new names (a decision beyond the ticket, see Notes)
Type: fix
Files: `src/scripts/veaf/veafCommands.lua`, `src/scripts/veaf/veafSpawnCore.lua`,
`src/scripts/veaf/veafSecurity.lua`, `test/lua/`

## The inversion

David's `REVIEW-SECURITY-LAYER` decision b: tiers renamed `OPEN` / `KNOWN_PILOT` / `SENIOR_PILOT` /
`ADMIN`, values unchanged, **old names kept as deprecated aliases for one release**. The doc
documents exactly that. The code does the opposite:

- `veafCommands.SECURITY_CHECKS = { L0, L1, L9, OPEN }` (`veafCommands.lua:83-97`) and
  `veafSpawn.SECURITY_CHECKS = { L9, L1, MM, OPEN }` (`veafSpawnCore.lua:137-152`) accept **only**
  the deprecated spellings; registering a handler with `"ADMIN"` fails the assert
  (`veafCommands.lua:116-121`).
- `veafSecurity.levelForName` — which does accept the new names via `LEVELS_BY_NAME`
  (`veafSecurity.lua:87`) — has **no production caller**; only the test file exercises it.

So the decided vocabulary exists in one unused function, and the whole dispatch surface still
speaks 2021.

## Fix

- Route both dispatchers' security-name resolution through `veafSecurity.levelForName` (or extend
  their `SECURITY_CHECKS` tables with the new names mapped to the same levels — pick whichever
  keeps the assert message helpful).
- New names canonical, old ones accepted with a deprecation warning logged once per name.
- `veafCommands.lua:78` comment still describes the removed "global `/login`" model — fix in
  passing (it is a comment inside the code being edited, not adjacent code).

## TDD

- Failing first: registering a command handler with `security = "ADMIN"` (and `"SENIOR_PILOT"`,
  `"KNOWN_PILOT"`, `"OPEN"`) must succeed in both dispatchers; `"L9"` must still succeed; an unknown
  name must still assert.

## Acceptance criteria

- [ ] Both dispatchers accept both vocabularies; tests pin the mapping equivalence
      (`ADMIN` ≡ `L9`, etc.).
- [ ] `test-lua` + stylua green; luacheck via CI.
- [ ] `DOC-AUDIT-FIXES` 01's note on this becomes deletable (the doc claim is now true).
