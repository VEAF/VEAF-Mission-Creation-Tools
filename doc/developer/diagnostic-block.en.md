# `veaf-tools doctor` — paste block format

> **Audience**: developers of the lots that consume `doctor`'s output — log analysis
> (`FEAT-SUPPORT-LOG-ANALYSIS`), which embeds it in its own report block, and bug intake
> (`FEAT-SUPPORT-BUG-INTAKE`), which parses it back.
>
> **Schema: `veaf-tools-doctor/1`.** — 🇫🇷 [`diagnostic-block.md`](diagnostic-block.md).

## Why a format {#why}

The block travels through Discord or a GitHub issue, copied by hand by someone who will not reread
it, and is read back by a machine at the other end. So it is neither a display nor a file: it is a
**contract**, versioned, that neither producer nor consumers can change on their own.

The implementation lives in `src/python/veaf-tools/veaf_libs/diagnostics.py`, producer
(`DiagnosticReport.to_block`) and reader (`parse_block`) in the same module — so they cannot drift —
with the round-trip test in `test/python/veaf_libs/test_diagnostics.py`.

## Structure {#structure}

```text
=== VEAF-TOOLS DOCTOR BEGIN ===
schema: veaf-tools-doctor/1
generated: 2026-09-05T09:39:29Z
tool.version: 6.19.0
...
--- recent-errors ---
2026-09-03 21:05:52,533 - veaf-tools - ERROR - Failed to evaluate time expression
Traceback (most recent call last):
ValueError: ...
--- recent-errors end ---
=== VEAF-TOOLS DOCTOR END ===
```

Three rules, and nothing else:

1. The block is delimited by `=== VEAF-TOOLS DOCTOR BEGIN ===` and `=== VEAF-TOOLS DOCTOR END ===`.
   It **arrives inside something else** (a message, code fences): a reader looks for those two
   lines, it does not assume the block starts at the first one.
2. Between the delimiters every line is `key: value`. The split is on the **first** `:` — a value
   may contain more of them (a Windows path, a timestamp).
3. The optional section between `--- recent-errors ---` and `--- recent-errors end ---` holds
   **raw text**. A record starts at a header line
   (`YYYY-MM-DD HH:MM:SS,mmm - <logger> - <LEVEL> - `); everything after it belongs to that record,
   which is how a stack trace survives whole.

## The fields {#fields}

The order is `FIELD_ORDER` in `diagnostics.py`, and it is stable.

| Key | Example | Reports `unknown` when |
|---|---|---|
| `schema` | `veaf-tools-doctor/1` | never |
| `generated` | `2026-09-05T09:39:29Z` | never |
| `tool.version` | `6.19.0` | the package is not installed and the version file is absent |
| `tool.packaging` | `frozen` or `source` | never |
| `tool.executable` | `C:\Users\<user>\...\python.exe` | the interpreter does not name itself |
| `tool.python` | `3.13.15` | never |
| `machine.os` | `Windows-11-10.0.26200-SP0` | the platform does not answer |
| `machine.locale` | `fr_FR / cp1252` | the locale cannot be determined |
| `machine.free_space` | `654.0 GB on D:\` | the disk does not answer |
| `dcs.detected` | `yes` / `no` | never |
| `dcs.version` | `2.9.29.27278` | DCS absent, or the banner is missing from `dcs.log` |
| `dcs.variant` | `stable`, `openbeta` | DCS absent |
| `dcs.write_dir` | `C:\Users\<user>\Saved Games\DCS` | DCS absent |
| `dcs.log_age` | `3 d` | DCS absent |
| `veaf.home` | `C:\Users\<user>\.veaf` | the folder cannot be created |
| `veaf.log` | `present, 1.2 MB` / `absent` | access fails |
| `veaf.lua_modules` | `37` | the inventory is unreadable |

An unavailable field is the string `unknown` and **never** an empty string: "absent" and "not
collected" read the same to a human, and a consumer must be able to tell them apart.

## Evolution rules {#evolution}

- **Adding** a field is compatible: a reader reads what it knows and ignores the rest. The producer
  already carries a field it does not itself know about.
- **Removing or renaming** one is not, and bumps the schema to `veaf-tools-doctor/2`.
- A reader **checks `schema` before parsing**. A block with an unknown schema is a block it can
  assume nothing about.

## Redaction {#redaction}

Everything `doctor` produces goes through `veaf_libs.redaction.redact` **before** it is displayed:
Windows account name → `<user>`, routable IPv4 address → `<ip>`, e-mail address → `<email>`, token
or password → `<redacted>`. Loopback addresses are kept: they carry nothing personal and do say
something useful.

Redaction happens at production, not at publication: by publication time it is a different program
on a different machine, and it is too late. A consumer may run `redact` again over what it receives
— the operation is idempotent — but must not rely on that to rescue an un-redacted source.
