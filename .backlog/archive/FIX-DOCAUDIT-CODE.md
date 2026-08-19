# FIX-DOCAUDIT-CODE — the code bugs the documentation audit surfaced

Status: ✅ done — 2026-08-13, all six tickets

Origin: the 2026-08-13 five-pass documentation audit. Cross-checking pages against code found
defects in the **code** — including one that inverts a decision David took, and two blind spots in
the `docs-check` gate itself, proven by the defects that survived it.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Tier names: the dispatchers refuse the decided vocabulary | ✅ |
| 02 | `_transport` demands the password from everyone | ✅ |
| 03 | Small dead ends: fog constant, stale CLI help | ✅ |
| 04 | Harden the two `docs-check` blind spots | ✅ |
| 05 | The generated mission.yaml repeats the security lie | ✅ |
| 06 | The radio-specs generator writes engine types as aircraft names | ✅ |

One branch, one PR. TDD throughout — each fix gets its failing test first.

## Sequencing note

Ticket 04 must land **before or with** `DOC-AUDIT-FIXES` 03/04: the hardened gate is what makes the
new CLI reference self-enforcing, and the anchor rule will catch the five dead anchors if the doc PR
has not fixed them yet (fine — CI red points at real defects).

## Observations parked here, not scoped (verify before acting)

- `veafCombatZone.lua:1423,1469` and `veafAssets.lua:58` register secured commands with
  `USAGE_ForAll`, but `veafRadio._proxyMethod` refuses a secured command with no `groupId`
  (`veafRadio.lua:291-295`) — worth a runtime probe: do those three entries work at all?
- `veafGrass.lua:241,1082,1200` omit `FARP_T` from the types `buildFarpsUnits` accepts (`:210`) —
  a `FARP_T` gets scenery but no warehouse fill. Needs a DCS check before calling it a bug.

## Definition of Done

- Lua: `test-lua` + stylua green; Python: full gate green, coverage ratchet respected.
- The doc claims that depended on these fixes become true (cross-check `DOC-AUDIT-FIXES` 01).

## What measurement changed, and the decisions taken alone

Recorded so a reviewer can overturn them rather than discover them.

- **Ticket 06's two proposed fixes were both wrong**, and one would have made the page worse.
  "Anchor at column 0" finds nothing at all — a datamine dump is one table indented by a tab —
  and `username` holds the DCS id, so preferring it produces exactly the "repeats the DCS id"
  symptom the ticket complains about. The field that works is `DisplayName`, measured present in
  all 170 unit files at the pinned ref. Ticket 01's `ADMIN ≡ L9` example was backwards too:
  `ADMIN` is the tightest tier and maps to `L0`.
- **Ticket 06's scope was wider than written.** The defect was described as a generated-page bug;
  `dcs-radio-specs.yaml` — the artifact the presets injector actually loads — carried the same 48
  wrong names.
- **VEAF's own 24 handler declarations were migrated to the new tier names** (ticket 01), which the
  ticket did not ask for. Left alone, our own modules would raise the deprecation notice that
  exists to warn a *mission maker*, making the signal unusable. The player-facing "give the L1
  password" messages are untouched: they name the configured password, not the tier.
- **Ticket 04's option rule is enabled for the updater only.** The mission-maker guide names 4 of
  the main CLI's 59 long options, because it is a guide and not a reference: pointing the rule
  there would report 110 defects on a page that is not the right place to fix them. The full CLI
  reference is `DOC-AUDIT-FIXES` ticket 04, and enabling the rule for it is one tuple entry —
  which is the "land with or before" this ticket asked for.

## Left armed, and stated rather than fixed

`radio_specs_updater.OUTPUT_MD` points at the **French** page, so `update-dcs-data --radio`
replaces hand-written French prose with a generated English page. This lot worked around it by
merging only the changed column, as ticket 06 instructed. The trap fires again at the next pin
bump. Fixing it properly means teaching the generator to emit both languages, or to write only the
table — a lot of its own, not a line of this one.

## Still parked, unchanged

The two observations above the Definition of Done both need a DCS session and neither was touched:
the three `USAGE_ForAll` secured commands that `veafRadio._proxyMethod` may refuse outright, and
`FARP_T` missing from the types `buildFarpsUnits` accepts.

---

## 01 — Tier names: the dispatchers refuse the decided vocabulary

Status: ✅ done — both dispatchers speak both vocabularies; VEAF's own 24 declarations migrated to the new names (a decision beyond the ticket, see Notes)
Type: fix
Files: `src/scripts/veaf/veafCommands.lua`, `src/scripts/veaf/veafSpawnCore.lua`,
`src/scripts/veaf/veafSecurity.lua`, `test/lua/`

### The inversion

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

### Fix

- Route both dispatchers' security-name resolution through `veafSecurity.levelForName` (or extend
  their `SECURITY_CHECKS` tables with the new names mapped to the same levels — pick whichever
  keeps the assert message helpful).
- New names canonical, old ones accepted with a deprecation warning logged once per name.
- `veafCommands.lua:78` comment still describes the removed "global `/login`" model — fix in
  passing (it is a comment inside the code being edited, not adjacent code).

### TDD

- Failing first: registering a command handler with `security = "ADMIN"` (and `"SENIOR_PILOT"`,
  `"KNOWN_PILOT"`, `"OPEN"`) must succeed in both dispatchers; `"L9"` must still succeed; an unknown
  name must still assert.

### Acceptance criteria

- [ ] Both dispatchers accept both vocabularies; tests pin the mapping equivalence
      (`ADMIN` ≡ `L9`, etc.).
- [ ] `test-lua` + stylua green; luacheck via CI.
- [ ] `DOC-AUDIT-FIXES` 01's note on this becomes deletable (the doc claim is now true).

---

## 02 — `_transport` demands the password from everyone, listed or not

Status: ✅ done — the marker id reaches the check; the doc caveat is deleted in both languages
Type: fix
Files: `src/scripts/veaf/veafTransportMission.lua`, `test/lua/test_veafTransportMission.lua`

### The bug

`veafTransportMission.lua:125` calls `veafSecurity.checkSecurity_L1(options.password)` **without
the `markId`**. `getMarkerSecurityLevel(nil)` then returns `-1` (`veafSecurity.lua:775-799`), so
the identity path can never grant anything and a pilot listed as `SENIOR_PILOT` in
`veaf-pilots.txt` — whose level is the whole point of the listing — still has to type the password
on every `_transport`.

Every other marker command passes its marker id and gets the per-player check. This one predates
the per-player model and was never rewired; the audit caught it because `veafSecurity.md`'s claim
("rien ne change pour un pilote listé") is false precisely here.

### Fix

Pass the marker id through to the security check, the way the other marker commands do (read one of
them for the exact call shape rather than assuming).

### TDD

- Failing first: a mocked identified marker author with level ≥ L1 and **no password** must pass
  the `_transport` security gate; an unidentified author without password must still fail.

### Acceptance criteria

- [ ] Listed pilot, no password → `_transport` accepted; unknown author, no password → refused.
- [ ] `test-lua` + stylua green.
- [ ] The caveat `DOC-AUDIT-FIXES` 01 adds to `veafSecurity.md` becomes deletable.

---

## 03 — Small dead ends: the fog constant, the stale CLI help

Status: ✅ done — fog constant fixed with an enumerated menu-wiring test; both stale CLI help strings corrected
Type: fix
Files: `src/scripts/veaf/veafWeather.lua`, `src/python/veaf-tools/veaf_build/cli.py`, tests

### The fog menu entry that references a constant that does not exist

`veafWeather.lua:1714` passes `veafWeather.FOG_ANIMATED_5_NO` — the generated grid produces
`FOG_ANIMATED_5M_NO` (the `M` is part of the pattern, `veafWeather.lua:1612`). The menu entry for
"animated fog, none" therefore hands `nil` to its handler. Fix the reference; add the test that
would have caught it (asserting every constant the menu wires actually exists on the module —
enumerated from the menu-building code, not sampled, per the sweep rule).

### The CLI help that names a command the updater does not have

`veaf_build/cli.py:238` and `:257` (the `--prerelease` help text and the `publish` docstring) tell
the user to run `veaf-tools-updater update --tag …` — the updater has **no subcommands**
(`veaf-tools-updater.py:891` is a bare `typer.run(main)`); the invocation is
`veaf-tools-updater --tag published-v<version>`. `TOOLS_REFERENCE.md` states this correctly; the
code's own help is the stale side. Fix both strings (and their i18n keys if routed through the
catalog).

### Acceptance criteria

- [ ] Fog: the enumerated menu-constant test fails before the fix, passes after; `test-lua` green.
- [ ] CLI: help strings corrected in both locales if localised; a grep for `updater update` over
      `src/` returns nothing.
- [ ] Full Python gate green.

---

## 04 — Harden the two `docs-check` blind spots the audit proved

Status: ✅ done — all four rules enforced; each verified by injecting its defect into a real page. The option rule is enabled for the updater only, and why is recorded in the code
Type: fix
Files: `veaf_build/docs_check.py`, `test/python/veaf_build/`

Both holes are proven by survivors, not hypothesised.

### A. An explicit anchor must retire the heading-derived slug

`anchors_of()` (`docs_check.py:117-119`) registers **both** the explicit `{#anchor}` and the slug
derived from the heading text. mkdocs' `attr_list` behaviour is that the explicit anchor
**replaces** the generated id — so a link to the heading-derived slug 404s on the site while the
gate validates it. Five dead anchors survived exactly this way (`TESTING.md:9` `#couverture` vs
`{#coverage}` is the cleanest specimen).

Fix: when a heading carries an explicit anchor, register **only** the explicit one. Expect the gate
to turn red on the five known survivors if `DOC-AUDIT-FIXES` 02 has not landed yet — red pointing at
real defects is the gate working.

### B. CLI coverage must key on options, not just command names

`check_doc_coverage` requires each command's **name** to appear in its reference page — so
`capture-map --parking` shipped 2026-08-12 with zero documentation and a green gate. Extend the
rule: for each typer command, every declared option's long name (`--parking`) must appear in the
reference page too. Source the option inventory from the typer signatures at check time (import or
AST — pick what the existing check already does for command names and stay consistent).

Sequencing: land with or before `DOC-AUDIT-FIXES` 04 (the full CLI reference) — the hardened rule is
what keeps that page honest when the 26th command arrives.

### TDD

- Failing first, A: a fixture page pair where a heading carries `{#explicit}` and a link targets
  the derived slug — must be reported.
- Failing first, B: a fixture command with an option absent from its reference page — must be
  reported; the option present — green.

### C. `slugify` strips underscores, and mkdocs does not

Found while enumerating the anchors for `DOC-AUDIT-FIXES` 02. `docs_check.slugify` (`:98`) does
`re.sub(r"[`*_]", "", title)` — the underscore is in there with the emphasis markers, so a heading
like ``### `build_variants:` `` is registered as `buildvariants`. mkdocs keeps it: `_` is a word
character for pymdownx, and the real id is `build_variants`.

Consequence today: every underscore heading is registered under a name the site does not use, so a
**correct** link to `#build_variants` is invisible to the gate — and would be *reported* if the gate
ever checked same-page links (see D). Roughly a dozen headings in `MISSION_YAML_REFERENCE` alone.

Fix: drop `_` from that character class. Emphasis with underscores (`_text_`) is not used in these
pages; verify with a grep before assuming, and if it is, strip it with a pattern that only matches
paired markers rather than every underscore.

### D. Same-page anchors are not checked at all

The 21-entry sweep that found C also established that a **dead same-page link** (`[x](#gone)` in the
page that should contain `#gone`) passes CI untouched: the gate validates cross-page anchors only.
Seven genuinely dead ones were fixed by hand in `DOC-AUDIT-FIXES` 02 — `developer/GUIDE.md` ×4,
`veafRadio.md`, `pilot/GUIDE.md`, `TESTING.md`, each a table-of-contents entry pointing at a
heading-derived slug whose heading carries an explicit anchor.

Fix: check same-page targets with the same rule as A (explicit anchor retires the derived slug).
Land it **after** C, or the underscore bug will bury the real findings in false positives — which is
exactly what happened to a hand-rolled version of this sweep during the audit.

### Acceptance criteria

- [ ] All four rules (A-D) enforced, with tests; `poetry run docs-check` green on the repo **after** the doc
      lot's fixes (and red before, on exactly the known defects — verify that, it is the proof).
- [ ] Full Python gate green; coverage ratchet respected.

---

## 05 — The generated `mission.yaml` repeats the security lie

Status: ✅ done — corrected, with a lockstep test against the shipped default
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

### Fix

Correct the emitted comment; keep it short enough to stay readable in a scaffolded file. Check
whether the string is localised (the generator writes a bilingual preamble elsewhere) and fix both
locales if so.

### TDD

- Failing first: generate a `mission.yaml` and assert the security comment does **not** claim that
  the password-free state is the default. Prefer asserting the corrected wording over asserting the
  absence of the old one, so the test says what is right rather than what was wrong.

### Acceptance criteria

- [ ] Generated output and the shipped default now agree with `veaf.lua:29`.
- [ ] Test in place; full Python gate green.

---

## 06 — The radio-specs generator writes engine types into its Aircraft column

Status: ✅ done — both artifacts corrected by merge; the ticket's two proposed fixes were disproved by measurement (see Findings)
Type: fix
Files: `veaf_build/radio_specs_updater.py`, `test/python/veaf_build/`, then the regenerated
`doc/mission-maker/dcs-radio-specs.{md,en.md}`

### The defect

`doc/mission-maker/dcs-radio-specs.md` is a **reference table** whose "Appareil" column holds engine
types on **72 of its 88 rows**: `TurboFan` for the A-10C, C-101CC, F-15ESE and F-16C_50, `TurboJet`
for some thirty Mirage F1 variants, `Piston` for the FW-190D9 — and where it is not an engine type it
simply repeats the DCS id (`| **A6E** | \`A6E\` |`). Found by the 2026-08-13 documentation audit.

The page is **generated** (`radio_specs_updater.py:35` → `OUTPUT_MD`), so this is a generator bug and
hand-editing the page would be undone by the next `update-dcs-data --radio`. That also makes it the
right place to fix: one regex, 72 rows.

### Cause

```python
# radio_specs_updater.py:305-307
# 'type = "..."' holds the aircraft's DCS display name at the top level of the file.
match = re.search(r'^\s*type\s*=\s*"([^"]+)"', lua_content, re.MULTILINE)
```

The comment says *top level of the file*; the regex says `^\s*`, which with `re.MULTILINE` matches an
**indented** `type = …` just as happily — including the one inside the engine block. The first match
in a datamine aircraft file is therefore often the engine's type, not the aircraft's name.

### Fix

Anchor the search where the comment already says it belongs (column 0, no leading whitespace), or
prefer the `username` field outright and keep `type` as the fallback rather than the primary. Decide
by reading a real datamine aircraft file — the pinned revision is in the module — rather than from
this ticket.

### Careful

`dcs-radio-specs` is a **hybrid artefact**: `update-dcs-data --radio` overwrites a manual layer and
has been known to drop hand-maintained entries (`MiG-15bis` / `MiG-15bis_FC`, `dcs_rejects_on_load`)
and to replace the hand-written French page with a generated English one. Generate at the pin into a
temp dir, diff, and merge only what changed — the result must be the column contents and nothing else.

### TDD

- Failing first: feed `parse_display_name` a Lua fixture whose engine block carries
  `type = "TurboFan"` above the aircraft's own name field, and assert the aircraft name comes back.

### Acceptance criteria

- [ ] `parse_display_name` returns the aircraft name for the fixture and for the four named real
      types; test in place.
- [ ] The page regenerated (merge, do not blind-overwrite), both languages, 88 rows carrying aircraft
      names; `docs-check` green.
- [ ] Full Python gate green.
