# 01 — Leftover-file triage + report annotation removal

Status: ✅ done (shipped in 6.7.1, #528)

## Tasks

- [ ] `_cleanup_legacy_v5_files` + `_archive_file_to_backup_v5`; call as convert() step 5.
- [ ] Report fields + `🧹 Legacy v5 files` report section + console output (unrecognized + secret).
- [ ] i18n keys (FR/EN): `convert_v5.cleanup.*`, `report.legacy_files.*`.
- [ ] Remove the annotated-missionConfig block from `to_markdown`; drop the field,
      the action append, the 3 unused i18n keys; update backup README.txt text.
- [ ] Tests: cleanup triage (tooling→backup, secret flag, regenerable delete, unrecognized
      listed/untouched, protected entries, src known-v6 exclusion, idempotence);
      report has no `~~~~lua` block but keeps the mapping tables.
- [ ] Migration guide note (FR/EN); CHANGELOG; PATCH bump.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
