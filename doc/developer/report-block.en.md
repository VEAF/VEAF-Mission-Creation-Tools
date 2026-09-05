# `veaf-logs` — report block format

> **Audience**: developers of the lots that produce or consume the `veaf-logs` paste block — log
> analysis (`FEAT-SUPPORT-LOG-ANALYSIS`), which writes it, and bug intake
> (`FEAT-SUPPORT-BUG-INTAKE`), which parses it back.
>
> **Schema: `veaf-logs-report/1`.** — 🇫🇷 [`report-block.md`](report-block.md).

## Why a second format {#why}

The [`doctor` block](diagnostic-block.en.md) describes **the machine**. This one describes **the
problem**: what the user was looking at, what the catalogue made of it, and what nobody could
explain. It *contains* the `doctor` block, it does not replace it.

Like it, this block travels through Discord or a GitHub issue, pasted by hand by someone who will
not reread it, and is parsed by a machine at the other end. It is therefore a **contract**,
versioned, that neither the producer nor the consumers can change alone.

The implementation lives in `src/python/veaf-tools/veaf_logs/report.py`, producer (`build_report`)
and reader (`parse_report_block`) in the same module — so they cannot drift apart — and the
round-trip test is in `test/python/veaf_logs/test_report.py`.

## Structure {#structure}

```text
=== VEAF-LOGS REPORT BEGIN ===
schema: veaf-logs-report/1
generated: 2026-09-05T09:39:29Z
excerpt.shown: 42
excerpt.selected: 3356
excerpt.total: 87989
excerpt.omitted: 3314
excerpt.excluded: levels=DEBUG,INFO,TRACE
catalogue.matched: damage_model,payload_weight
catalogue.uncatalogued: 24
proposals.count: 2
truncated: sections retirées pour tenir dans un message : proposals, analysis
--- doctor ---
=== VEAF-TOOLS DOCTOR BEGIN ===
schema: veaf-tools-doctor/1
...
=== VEAF-TOOLS DOCTOR END ===
--- doctor end ---
--- excerpt ---
[veaf-logs] 42 entrées sur 87989 indexées (3356 retenues, 3314 omises par la limite de taille)
masqué (✕) — niveaux : DEBUG, INFO, TRACE
16:28:35.388 ERROR      ED_SOUND     can't load proto file "/sounds/54/sdef/..."
--- excerpt end ---
--- catalogue ---
Motifs connus (texte du catalogue, tel quel) :
- Modèle de dégâts corrompu (damage_model) ×3 : Modules tiers dont le modèle de dégâts...
--- catalogue end ---
=== VEAF-LOGS REPORT END ===
```

The block's own prose is French: `veaf-logs` is a French-language application, and its output is
what the user pastes. Only the field **names** are part of the contract.

Four rules, and nothing else:

1. The block is delimited by `=== VEAF-LOGS REPORT BEGIN ===` and `=== VEAF-LOGS REPORT END ===`.
   It **arrives in the middle of something else**: a reader looks for those two lines, it does not
   assume the block starts at line one. It is usually wrapped in a ` ```text ` code fence; any triple
   backtick in the content is replaced by three apostrophes, otherwise it would close the fence
   early.
2. Between the delimiters, and **outside the sections**, every line is `key: value`, split on the
   first `:`, on a single line. Same rule as the `doctor` block and for the same reason: a value
   carrying a newline would come back as two fields, the second of them forged.
3. A section is bounded by `--- <name> ---` and `--- <name> end ---` and holds **raw text**. The
   names are those of `SECTIONS`: `doctor`, `excerpt`, `catalogue`, `analysis`, `proposals`. An
   empty section is not written at all — its absence is information, not an oversight.
4. The `doctor` section carries a complete `veaf-tools-doctor/1` block, delimiters included. The two
   sets of delimiters are deliberately different: a reader looking for one never trips over the
   other, and the nested block reads back with `parse_block` with no special care.

## The fields {#fields}

The order is that of `FIELD_ORDER` in `report.py`, and it is stable.

| Key | Example | What it says |
|---|---|---|
| `schema` | `veaf-logs-report/1` | check it **before** reading anything else |
| `generated` | `2026-09-05T09:39:29Z` | when the block was produced, in UTC |
| `excerpt.shown` | `42` | records actually present in the `excerpt` section |
| `excerpt.selected` | `3356` | records the filters kept, before the size ceiling |
| `excerpt.total` | `87989` | records indexed in the log — the denominator |
| `excerpt.omitted` | `3314` | records kept by the filters but dropped by the ceiling |
| `excerpt.excluded` | `levels=DEBUG,INFO` | categories set to ✕, or `aucune` |
| `catalogue.matched` | `damage_model,...` | ids of the `rules.json` entries recognised, or `aucun` |
| `catalogue.uncatalogued` | `24` | records the catalogue does not explain |
| `proposals.count` | `2` | recurring uncatalogued patterns spotted |
| `truncated` | `non` | or the list of sections dropped, or `OUI — …` |

`excerpt.excluded` is the field to read first after the schema: it says what the excerpt **cannot**
contain. A report where `catalogue.uncatalogued` is 0 and `excerpt.excluded` names `ERROR` does not
describe a clean log, it describes a log whose errors were hidden.

## What happens when it does not fit {#truncation}

The block is built to fit one Discord message — 2 000 characters, code fence included. A full
excerpt is more than ten times that: measured on 2026-09-05 against an 11.1 MB `dcs.log` (87 989
records), the default excerpt renders to ~16 000 characters.

The sacrifice order is therefore fixed, and asymmetric:

1. `proposals`, then `analysis`, then `catalogue` are dropped **whole**;
2. the excerpt is then **shrunk** to whatever room is left, never dropped while there is room to
   show a few records;
3. as a last resort the `doctor` block's error records go, but **never its fields**: they are the
   half of the report nobody can reconstruct afterwards.

The `truncated` field names what went at each step. A block cut at the boundary reads like a
complete one to whoever receives it, so there is no such cut.

## Redaction {#redaction}

The block is redacted **assembled**, not only part by part. The two are not equivalent: the excerpt
is already redacted at construction, but the model's commentary arrives from the network and has
been through nothing else. The redaction is that of
[`veaf_libs.redaction`](diagnostic-block.en.md#redaction) — the only one in the project, and it is
idempotent, so a second pass over already-treated parts damages nothing.

## What the reader may assume {#untrusted}

**Nothing.** The block travels through a public issue and anyone can type one by hand. The producer
guarantees the *shape* — one field, one line — never the truth of a value. A consumer acting on
`excerpt.total` is acting on a claim, not on a reading taken from the machine.

`parse_report_block` raises `ValueError` on a missing block or one without its end delimiter — a
truncated paste, which must be reported rather than half-read. A section left open is however
returned with what was read: losing the content as well as the ending would be doubly punishing.
