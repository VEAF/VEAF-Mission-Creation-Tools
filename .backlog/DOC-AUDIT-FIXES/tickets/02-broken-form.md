# 02 — Broken form: rendering, dead anchors, escaped links, prose

Status: ⬜ ready
Type: fix
Files: ~20 pages ×2 languages under `doc/`

Form defects only — nothing here changes a claim. Every anchor below was verified against the real
slugifier (`pymdownx.slugs.slugify(case=lower)` + `attr_list`); `docs-check` structurally cannot see
them because `anchors_of()` registers both the explicit anchor **and** the heading-derived slug
(hardening → `FIX-DOCAUDIT-CODE` 04).

## A. Rendering-breaking

- [ ] `LUA_API_REFERENCE.md:3-5` and ~40 further `**Key:** value` line runs (+ 42 in EN) — consecutive
      lines with no blank line collapse into one `<p>`; the browser shows them run-on. Convert each
      block to a list or add hard breaks; fix the generator if these blocks are generated
      (`veaf_build/` — check before hand-editing).
- [ ] `dcs-radio-specs.md:106` region, 72 of 88 rows (+ EN) — the "Appareil" column holds engine
      types (`TurboFan`, `TurboJet`, `Piston`) or repeats the DCS ID. Datamine artifact; regenerate
      or correct the column at its source (check whether this page is generated before editing).
- [ ] `AI_ASSISTANT_INSTALL.md:52` (+ EN `:49`) — corrupted path
      `extensionseaf-mission-editor` → `extensions\veaf-mission-editor`.
- [ ] `MIGRATION_GUIDE.md:79` (FR) — trailing `\\` in a Copy-Item command.
- [ ] Dead anchors (5): `TESTING.md:9` `#couverture` → `#coverage` · `pilot/GUIDE.md:12`
      `#les-commandes-par-marqueur` → `#marker-commands` · `pilot/GUIDE.md:9` off-by-one slug
      (`#quest-ce-que-veaf-mct-` with trailing hyphen — give the heading an explicit anchor
      instead) · `MISSION_YAML_REFERENCE.md:717` + `.en.md:731` `#custom_scripts` →
      `#custom-scripts`.
- [ ] Links escaping `docs_dir` (4 → 404 on the site): `CONVERT_OTHER.md:50` (+ EN) ADR 0007 → the
      absolute GitHub URL like every other ADR link · `mission-maker/GUIDE.md:690` (+ EN `:691`)
      `tools/klogg/veaf.conf` → GitHub URL.
- [ ] `PIPELINE_REFERENCE.md` (+ EN) — steps ordered 1,2,3,**6**,4,5 against the page's own "dans
      cet ordre"; renumber or move the section; give steps 4-5 explicit `{#…}` anchors like their
      siblings.
- [ ] `TOOLS_REFERENCE.md:853-869` (+ EN) — the page signs off ("Bonnes publications ! 🚀") and then
      continues; move the farewell to the end; delete the duplicated language-detection section
      (`:859-869` repeats `:171-193` verbatim); rebuild the ToC (4 of ~20 sections, wrong order) —
      or drop the manual ToC entirely (mkdocs renders one).

## B. Meaning-blurring prose (not factual, just wrong-reading)

- [ ] `mission-maker/GUIDE.md:684` — "éditez `veaf-config.lua` — c'est un fichier généré, donc vos
      modifications seront écrasées" — the advice destroys itself; rewrite as the warning it is.
- [ ] `MIGRATION_GUIDE.md:126-132` — "n'existent plus ou ont été renommées" introducing rows marked
      "inchangé"; reframe the section.
- [ ] `PIPELINE_REFERENCE.md:339` (FR) — garbled sentence ("en restreint un seul"); EN has the
      meaning.
- [ ] `MISSION_YAML_REFERENCE.md:150` — misplaced "au contraire".
- [ ] `pilot/GUIDE.md:50` vs `:62,:193` — "TOUTES les fonctions sous F10 → VEAF" vs CARRIER OPS
      hanging off F10 directly (+ EN).
- [ ] `index.md:42` — TOOLS_REFERENCE mislabelled as the `veaf-tools.exe` reference (becomes true
      only after ticket 04; fix the label with it) — plus `mission-maker/GUIDE.md:697`,
      `MIGRATION_GUIDE.md:378`.
- [ ] Module count said four ways (33+/30+/17+/34) — one number, counted, everywhere; same for the
      aircraft count (ticket 01 fixes it to 100).

## C. Typos, franglais, consistency (the audit's itemised 30 + 12)

- [ ] FR grammar: "une 2e radio" (`PIPELINE_REFERENCE.md:108,120`) · stray tutoiement
      (`mission-maker/GUIDE.md:359`) · "faire verrouiller **par** les administrateurs"
      (`GUIDE.md:294`, dies anyway with ticket 01's purge) · "une fois qu'elles sont toutes
      détruites" (`pilot/GUIDE.md:223`) · "Ils portent" (`ALIASES.md:210`) · `<nom-préréglage>`
      accent (`PIPELINE_REFERENCE.md:143`) · "spawnables" plural (`MIGRATION_GUIDE.md:268`) ·
      em-dash+comma (`GUIDE.md:570`) · colon-promising-list (`pilot/GUIDE.md:277`) · missing full
      stop (`CONVERT_OTHER.md:11`).
- [ ] Franglais: "stabilotées"/"stabilo" → surlignées (`PIPELINE_REFERENCE.md:190,203`) ·
      "droppant" (`:215`) · "misroutait" (`:339`) · "committée" (`:543`) · commiter/committer
      unified (`TOOLS_REFERENCE.md ×6`) · "aliases" → alias (`MIGRATION_GUIDE.md:229,292`) ·
      "plancher de cliquet" → plancher à cliquet / seuil plancher (`TESTING.md:273`) · "slash
      commands" (`AI_ASSISTANT_INSTALL.md:22`) · carrier/tankers/Actifs vs
      porte-avions/ravitailleurs/Ressources unified (`mission-maker/GUIDE.md:37-38,488`) ·
      "insurgée" (`ALIASES.md:45`).
- [ ] Typography/wording: "Linux–macOS" en-dash (`TOOLS_REFERENCE.md:178,866` + EN) · "protège
      enfin" without object (`ROADMAP.md:44` — dies with ticket 03's pointer) · "ligne par ligne"
      vs per-file (`TESTING.md:64`) · duplicated parenthetical (`ALIASES.md:103`) · verbless tanker
      row (`ALIASES.md:158`) · FW-190A8 vs D9 example mismatch (`dcs-radio-specs.md:69,76`).
- [ ] EN: guillemets (`TOOLS_REFERENCE.en.md:75`) · ASCII hyphens as dashes (`:1,7,8,43`) · "makes
      missions alive" → brings to life (`pilot/GUIDE.en.md:25`) · BrE/AmE left as-is (not worth the
      churn) unless touching the line anyway.
- [ ] The ~12 minor items: EN shell comments on FR page (`TOOLS_REFERENCE.md:528-638`) · v6.3.0
      before v6.3.3 (`ROADMAP.md` — dies with ticket 03) · duplicate `### Prérequis` anchors
      (`TESTING.md:46,74` + EN) · localised map-name mix (`FOOTHOLD.md:25-26`) · two Klogg menu
      paths (`GUIDE.md:690` vs `MIGRATION_GUIDE.md:365`) · catalogue/catalog
      (`mission-maker/README.en.md:61,73`) · Véhicule vs Escouade for `-sa15`/`-sa22`
      (`pilot/GUIDE.md:100-101` vs `ALIASES.md:39,42`) · `size [1-5]` vs table starting at 0
      (`pilot/GUIDE.md:264,271`) · `mission build mission .` (`MIGRATION_GUIDE.md:205,246` + EN) ·
      duplicated intro sentences (`index.md:3,5`).

## Acceptance criteria

- [ ] `docs-check` green; a manual `mkdocs build` (or the CI docs job) renders LUA_API_REFERENCE's
      header blocks as separate lines.
- [ ] The five dead anchors resolve on the rendered site (explicit anchors added where slugs were
      fragile).
- [ ] CHANGELOG entry (shared with ticket 01's PR); version bump with it.
