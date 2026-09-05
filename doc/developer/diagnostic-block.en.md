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
   may contain more of them (a Windows path, a timestamp). A key and a value each hold to **one
   line**: the producer collapses any line break to a space, without which a multi-line value would
   come back as two fields, one of them written by nobody.
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

## A block you received is not a measurement {#untrusted}

`parse_block` reads text that arrived through a public issue or a Discord message. Anyone can type
one by hand. The producer guarantees the **shape** (one field, one line), never the **truth** of a
value: a consumer acting on `tool.version` is acting on a claim, not on a reading taken from the
machine. That is a trust boundary, not a parsing detail — `FEAT-SUPPORT-BUG-INTAKE` is the first lot
to cross it.

## Redaction {#redaction}

Everything `doctor` produces goes through `veaf_libs.redaction.redact` **before** it is displayed:
account name → `<user>`, routable IP address (v4 and v6) → `<ip>`, e-mail address → `<email>`, token
or password → `<redacted>`. Loopback addresses are kept: they carry nothing personal and do say
something useful.

Two asymmetric rules, and the asymmetry is deliberate.

**Identity is over-redacted.** The account name is replaced everywhere it appears, not only under
`Users/`: it resurfaces in a temporary directory (`Temp\pytest-of-Firstname\`), in a host name, in
an environment dump. Measured over 1489 real `ERROR` records it survived **56 times** on lines whose
originating path had been redacted three segments earlier.

**Identifiers are not redacted.** There is deliberately **no** entropy rule here. A first version
replaced any run of 24 or more characters mixing letters and digits. Measured against the same log
it produced **74 substitutions and not one credential**; measured against the repository's own data
files it matched 169 DCS GUIDs and 493 other identifiers, among them `HVAR_USN_Mk28_Mod4_Corsair`
and `M261_INBOARD_DE_M151_C_M274`. That is `unknown payload <redacted>`: keeping "it broke" and
throwing away "on what". A secret is therefore recognised by its **context** (an assignment to a
credential-shaped key — `token`, `password`, `access_token`, `client_secret`…) or by a **known
shape** (a GitHub token prefix, a JWT, a webhook URL, credentials inside a URL). An unlabelled blob
of randomness in an unknown shape goes through, on purpose.

Redaction happens at production, not at publication: by publication time it is a different program
on a different machine, and it is too late. A consumer may run `redact` again over what it receives
— the operation is idempotent — but must not rely on that to rescue an un-redacted source.
