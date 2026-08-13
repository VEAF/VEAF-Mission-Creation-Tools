# 04 — The full CLI reference: 25 commands, options included

Status: ⬜ ready
Type: feat
Files: a new `doc/CLI_REFERENCE.md` + `.en.md` (or a rebuilt TOOLS_REFERENCE §), `mkdocs.yml`,
cross-links from GUIDE / index / MIGRATION_GUIDE

David's call (2026-08-13, arbitration c): full command documentation is wanted **in addition to**
`--help`. Today `TOOLS_REFERENCE` covers 3 commands of 25 while three pages link to it as the
"référence complète"; the only honest inventory is the GUIDE's one-line-per-command table.

## Shape

- One page, both languages, one `###` section per command, grouped as `command_tree.py` groups them
  (`mission` / `convert` / `content` / `cockpit` / `dcs` + the 4 root commands), with the grouped
  spelling (`veaf-tools convert v5`) primary and the legacy flat alias noted once.
- Per command: one-sentence purpose (from the i18n help key, rewritten for prose), the arguments and
  options table (name, type, default, envvar where one exists), one realistic example, and a link to
  the owning long-form page (GUIDE section, PIPELINE_REFERENCE step, developer page) where one
  exists — this page is the *reference*, not the tutorial.
- Source of truth: `src/python/veaf-tools/veaf_tools/commands/*.py` typer signatures — enumerate,
  do not sample. The audit already extracted several inventories (capture-map's 6 options,
  update-dcs-data's 14, the updater's 8) — re-verify at writing time rather than trusting.

## Consistency obligations

- Retitle/redirect: `index.md:42`, `mission-maker/GUIDE.md:384,697`, `MIGRATION_GUIDE.md:378` point
  their "référence CLI" promises at this page; `TOOLS_REFERENCE` keeps the updater +
  `veaf-build` + release content under an honest title (ticket 02 already fixes its internal form).
- The `docs-check` CLI-coverage rule keys on command names — after `FIX-DOCAUDIT-CODE` 04 it will
  also key on option names. Land this with or after the gate hardening and it becomes
  self-enforcing for the next command someone adds.

## Acceptance criteria

- [ ] All 25 commands present, options enumerated from the typer signatures, both languages, in nav.
- [ ] The three "référence complète" links point here; `docs-check` green.
- [ ] CHANGELOG entry; version bump (shared with ticket 03's PR).
