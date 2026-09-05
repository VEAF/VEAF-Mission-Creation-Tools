# 02 — Attachments become bounded, redacted material

Status: ✅ done

Type: feat

## The problem

The reports worth having come with files: #215 carried a `dcs.log`, two `~mis*.zip` and the full
mission. That is what makes a bug reproducible. But a raw `dcs.log` is measured at **11.1 MB** on
David's machine, and a `.miz` is a binary archive — neither can be handed to a model, and neither
can be left as a Discord link, since those URLs are signed and expire.

## What to build

- **Download** the attachments of the thread, with a size ceiling and an accepted-type list.
- **Filter the log** with the rules that already exist rather than new ones:
  [`veaf_logs/rules.json`](../../../src/python/veaf-tools/veaf_logs/rules.json) and the *Diagnostic*
  profile. The excerpt builder from
  [`FEAT-SUPPORT-LOG-ANALYSIS` ticket 01](../../FEAT-SUPPORT-LOG-ANALYSIS/tickets/01-bounded-excerpt.md)
  is the same job on the same material — share it, do not fork it.
- **Summarise a mission** through the existing `.miz` export to JSON/YAML rather than by reading
  bytes: modules enabled, zones, groups, versions. A structured summary is both cheaper and more
  useful than a binary blob.
- **Redact** everything before it goes anywhere: user paths, addresses, tokens, session identifiers.
- **Re-upload** the files to the issue itself, so the report survives the expiry of Discord's links.
  What is attached to the issue is the redacted material, and the ticket records what was stripped.

## Notes

- A `.miz` can carry mission passwords and module settings. Summarising through the export path
  makes it possible to decide field by field what is published; dumping the archive does not.
- An attachment that is too large, of an unexpected type, or unreadable is reported to the user as
  such — the flow continues without it rather than failing.
- Everything read here is **data, not instruction**, per [ticket 01](01-form-and-extraction.md).

## Definition of done

- [x] Download with size ceiling and type allow-list
- [x] Log filtering reusing the shared excerpt builder, not a second implementation
- [x] Mission summarised through the existing export, with the published field set decided explicitly
- [x] Redaction applied to every artefact before it leaves the service
- [x] Files re-uploaded to the issue; no reliance on Discord URLs surviving
- [x] Oversized, unknown and corrupt attachments each handled without aborting the flow
- [x] Unit tests on a large synthetic log, a real-shaped `.miz`, and each rejection path
- [x] Quality gate clean
