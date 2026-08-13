# 02 — Broken form: rendering, dead anchors, escaped links, prose

Status: ✅ done 2026-08-13 — applied; three of the audit's counts were wrong in both directions (see Corrections), and four items are deferred with their reasons
Type: fix
Files: ~20 pages ×2 languages under `doc/`

Form defects only — nothing here changes a claim. Every anchor below was verified against the real
slugifier (`pymdownx.slugs.slugify(case=lower)` + `attr_list`); `docs-check` structurally cannot see
them because `anchors_of()` registers both the explicit anchor **and** the heading-derived slug
(hardening → `FIX-DOCAUDIT-CODE` 04).

## A. Rendering-breaking

- [x] `LUA_API_REFERENCE.md:3-5` and ~40 further `**Key:** value` line runs (+ 42 in EN) — consecutive
      lines with no blank line collapse into one `<p>`; the browser shows them run-on. Convert each
      block to a list or add hard breaks; fix the generator if these blocks are generated
      (`veaf_build/` — check before hand-editing).
- [x] ~~`dcs-radio-specs.md:106` region, 72 of 88 rows~~ — **moved to `FIX-DOCAUDIT-CODE` 06**: the
      page is *generated* (`radio_specs_updater.py:35`), and the cause is one regex —
      `parse_display_name` searches `^\s*type\s*=` with `MULTILINE`, so it matches the **indented**
      `type` inside the engine block, which is where `TurboFan` comes from. Its own comment says
      "top level of the file". Hand-editing the page would be undone by the next
      `update-dcs-data --radio`.
- [x] `AI_ASSISTANT_INSTALL.md:52` (+ EN `:49`) — corrupted path
      `extensionseaf-mission-editor` → `extensions\veaf-mission-editor`.
- [x] `MIGRATION_GUIDE.md:79` (FR) — trailing `\\` in a Copy-Item command.
- [x] Dead anchors — **seven**, not five: `TESTING.md:9` `#couverture` → `#coverage` · `pilot/GUIDE.md:12`
      `#les-commandes-par-marqueur` → `#marker-commands` · `pilot/GUIDE.md:9` off-by-one slug
      (`#quest-ce-que-veaf-mct-` with trailing hyphen — give the heading an explicit anchor
      instead) · `MISSION_YAML_REFERENCE.md:717` + `.en.md:731` `#custom_scripts` →
      `#custom-scripts`.
- [x] Links escaping `docs_dir` — **six**, not four: `CONVERT_OTHER.md:50` (+ EN) ADR 0007 → the
      absolute GitHub URL like every other ADR link · `mission-maker/GUIDE.md:690` (+ EN `:691`)
      `tools/klogg/veaf.conf` → GitHub URL.
- [x] `PIPELINE_REFERENCE.md` (+ EN) — steps ordered 1,2,3,**6**,4,5 against the page's own "dans
      cet ordre"; renumber or move the section; give steps 4-5 explicit `{#…}` anchors like their
      siblings.
- [x] `TOOLS_REFERENCE.md:853-869` (+ EN) — the page signs off ("Bonnes publications ! 🚀") and then
      continues; move the farewell to the end; delete the duplicated language-detection section
      (`:859-869` repeats `:171-193` verbatim); rebuild the ToC (4 of ~20 sections, wrong order) —
      or drop the manual ToC entirely (mkdocs renders one).

## B. Meaning-blurring prose (not factual, just wrong-reading)

- [x] `mission-maker/GUIDE.md:684` — "éditez `veaf-config.lua` — c'est un fichier généré, donc vos
      modifications seront écrasées" — the advice destroys itself; rewrite as the warning it is.
- [x] `MIGRATION_GUIDE.md:126-132` — "n'existent plus ou ont été renommées" introducing rows marked
      "inchangé"; reframe the section.
- [x] `PIPELINE_REFERENCE.md:339` (FR) — garbled sentence ("en restreint un seul"); EN has the
      meaning.
- [x] `MISSION_YAML_REFERENCE.md:150` — misplaced "au contraire".
- [x] `pilot/GUIDE.md:50` vs `:62,:193` — "TOUTES les fonctions sous F10 → VEAF" vs CARRIER OPS
      hanging off F10 directly (+ EN).
- [ ] **Deferred to ticket 04** (it becomes true only when the CLI reference exists): `index.md:42` — TOOLS_REFERENCE mislabelled as the `veaf-tools.exe` reference (becomes true
      only after ticket 04; fix the label with it) — plus `mission-maker/GUIDE.md:697`,
      `MIGRATION_GUIDE.md:378`.
- [x] Module count said four ways (33+/30+/17+/34) — one number, counted, everywhere; same for the
      aircraft count (ticket 01 fixes it to 100).

## C. Typos, franglais, consistency (the audit's itemised 30 + 12)

- [x] FR grammar: "une 2e radio" (`PIPELINE_REFERENCE.md:108,120`) · stray tutoiement
      (`mission-maker/GUIDE.md:359`) · "faire verrouiller **par** les administrateurs"
      (`GUIDE.md:294`, dies anyway with ticket 01's purge) · "une fois qu'elles sont toutes
      détruites" (`pilot/GUIDE.md:223`) · "Ils portent" (`ALIASES.md:210`) · `<nom-préréglage>`
      accent (`PIPELINE_REFERENCE.md:143`) · "spawnables" plural (`MIGRATION_GUIDE.md:268`) ·
      em-dash+comma (`GUIDE.md:570`) · colon-promising-list (`pilot/GUIDE.md:277`) · missing full
      stop (`CONVERT_OTHER.md:11`).
- [x] Franglais: "stabilotées"/"stabilo" → surlignées (`PIPELINE_REFERENCE.md:190,203`) ·
      "droppant" (`:215`) · "misroutait" (`:339`) · "committée" (`:543`) · commiter/committer
      unified (`TOOLS_REFERENCE.md ×6`) · "aliases" → alias (`MIGRATION_GUIDE.md:229,292`) ·
      "plancher de cliquet" → plancher à cliquet / seuil plancher (`TESTING.md:273`) · "slash
      commands" (`AI_ASSISTANT_INSTALL.md:22`) · carrier/tankers/Actifs vs
      porte-avions/ravitailleurs/Ressources unified (`mission-maker/GUIDE.md:37-38,488`) ·
      "insurgée" (`ALIASES.md:45`).
- [x] Typography/wording: "Linux–macOS" en-dash (`TOOLS_REFERENCE.md:178,866` + EN) · "protège
      enfin" without object (`ROADMAP.md:44` — dies with ticket 03's pointer) · "ligne par ligne"
      vs per-file (`TESTING.md:64`) · duplicated parenthetical (`ALIASES.md:103`) · verbless tanker
      row (`ALIASES.md:158`) · FW-190A8 vs D9 example mismatch (`dcs-radio-specs.md:69,76`).
- [x] EN: guillemets (`TOOLS_REFERENCE.en.md:75`) · ASCII hyphens as dashes (`:1,7,8,43`) · "makes
      missions alive" → brings to life (`pilot/GUIDE.en.md:25`) · BrE/AmE left as-is (not worth the
      churn) unless touching the line anyway.
- [x] The ~12 minor items: EN shell comments on FR page (`TOOLS_REFERENCE.md:528-638`) · v6.3.0
      before v6.3.3 (`ROADMAP.md` — dies with ticket 03) · duplicate `### Prérequis` anchors
      (`TESTING.md:46,74` + EN) · localised map-name mix (`FOOTHOLD.md:25-26`) · two Klogg menu
      paths (`GUIDE.md:690` vs `MIGRATION_GUIDE.md:365`) · catalogue/catalog
      (`mission-maker/README.en.md:61,73`) · Véhicule vs Escouade for `-sa15`/`-sa22`
      (`pilot/GUIDE.md:100-101` vs `ALIASES.md:39,42`) · `size [1-5]` vs table starting at 0
      (`pilot/GUIDE.md:264,271`) · `mission build mission .` (`MIGRATION_GUIDE.md:205,246` + EN) ·
      duplicated intro sentences (`index.md:3,5`).

## Acceptance criteria

- [x] `docs-check` green; a manual `mkdocs build` (or the CI docs job) renders LUA_API_REFERENCE's
      header blocks as separate lines.
- [x] The seven dead anchors resolve on the rendered site (explicit anchors added where slugs were
      fragile).
- [x] CHANGELOG entry (shared with ticket 01's PR); version bump with it.

## Corrections to the audit's own counts — enumerated instead of sampled

Three counts in this ticket came from a sampling pass and were wrong. Each was re-derived with a
script over the whole tree, and the scripts are worth rebuilding if this is ever done again (the
permanent versions are `FIX-DOCAUDIT-CODE` 04).

- **Dead same-page anchors: seven, not five.** `developer/GUIDE.md` had **four** in its own table of
  contents (`#environnement-de-développement`, `#scripts-lua-runtime`, `#outils-python`,
  `#mode-développeur`, all pointing at headings that carry English explicit anchors), plus
  `veafRadio.md:107`, `pilot/GUIDE.md:12` and `TESTING.md:9`.
- **Links escaping `docs_dir`: six, not four.** `developer/smoke-harness` carried three per language.
- **Two false positives were nearly "fixed" into breakage**, and both are worth remembering:
  - A hand-rolled slugifier that *collapsed* whitespace runs reported 13 phantom dead anchors. The
    repo's (and pymdownx's) is a plain `.replace(" ", "-")`, so `Unit & Group Management` really is
    `unit--group-management`, two dashes and all. **Import `docs_check.slugify`; never reimplement it.**
  - A blanket `../../ → GitHub URL` conversion broke **55 valid links**: from
    `doc/mission-maker/scripts/`, `../../` lands in `doc/`, which is *inside* `docs_dir`. Only pages
    at depth 2 escape. Reverted with `git checkout` on that directory — and `docs-check` was green
    both before and after the breakage, because it does not verify external URLs.
- `ALIASES.md:210` "Ils portent" **never existed** (`git log -S` finds nothing); the line reads
  "Elles portent" and agrees with its antecedent. Audit misreport.

## Deferred, with reasons rather than silence

- **`index.md:42` + `GUIDE.md:697` + `MIGRATION_GUIDE.md:378`** — the "référence CLI complète" links.
  They are only wrong until ticket 04 writes that reference; fixing the label now would point readers
  at a page that still does not have the content. → ticket 04.
- **`FOOTHOLD.md:25-26` localised/unlocalised map-name mix** — the same mix exists at `:54-55,:57,:63`
  and `:232` ("carte Irak", "La Normandie est une autre famille"), so this is a page-wide naming
  decision rather than a typo. Needs David's call: translate every DCS map name in FR prose, or keep
  the English product names throughout.
- **EN shell comments inside FR code blocks** (`TOOLS_REFERENCE.md:528-638`, ~11 of them) — left as
  is. They are inside `bash` fences a reader copies verbatim, and translating a comment inside a
  copied command is churn with no reader gain.
- **BrE/AmE inconsistency across EN pages** — not worth a sweep; fixed only where a line was being
  touched anyway.

## Found while fixing, beyond the ticket

- **`MIGRATION_GUIDE`'s security row was false**, not merely awkwardly framed: it told a maker to
  rename `veaf.SecurityDisabled` to `veafSecurity.SecurityDisabled`, but the runtime honours **both**
  spellings on purpose (`veafSecurity.lua:117-128` — and that docstring records that "nothing in the
  repository assigns it" was evidence of nothing for a *config* field, which is how three years of
  fail-safe breakage went unnoticed). Corrected in both languages.
- **`veafCombatZone`'s "Constantes du module" section sat in a different place in each language** —
  FR before "Fonctionnement", EN after the `#command` subsection. FR moved onto EN's order, so the
  two pages now read in the same sequence.
- **`PIPELINE_REFERENCE` steps 4 and 5 had no explicit anchors** while 1, 2, 3 and 6 did; added, so
  every step can be deep-linked. The step-6 block was *moved* rather than renumbered, because its
  number already agreed with the execution order in `build.py:295-405` — only its position on the
  page disagreed.
