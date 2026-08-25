---
Status: 🔄 in-progress
---

# DOC-CTLD-TOOLS-DOWNLOAD — the documentation never says where to get `ctld-tools`

## Problem

Since ADR 0016, a mission's CTLD configuration lives in `ctld-config.yaml` and is authored
with `ctld-tools.exe`. The mechanism is documented in both languages — the guide has a
dedicated section, the YAML reference and the migration guide point at it, `validate` and the
builder both name the replacement. What no page states is **how a mission maker obtains the
tool**, which is the first step of the whole procedure.

Raised by a real question (Tripack, 2026-08-25: "can I use ctld-tools to configure CTLD in a
VMCT mission?"). The answer is yes, and the documentation supports every part of it except
the download.

Four concrete gaps, each verified:

1. **No download location anywhere.** The guide says `ctld-tools.exe` is "shipped with CTLD"
   and links `https://github.com/VEAF/CTLD`. The executable is a *release asset* — confirmed
   present in `published-v2.0.0-rc7` — but **every CTLD 2 release is a pre-release**, so none
   appears as "Latest release" on the repository landing page. Following our link does not
   lead to the file.
2. **The prerequisites table does not list it** (`GUIDE.md` "Prérequis"), although it lists
   VS Code.
3. **Nothing states which version to take.** A "CTLD dev build" release exists, newer than the
   vendored engine. No page says to match the tool to the CTLD version VMCT ships, nor how to
   read that version — it is in the header of `published/src/scripts/community/CTLD.lua`
   (`Version : 2.0.0-rc7`), which no page mentions.
4. **The builder's own message dead-ends.** `builder.ctld_no_config` says "Create one with
   ctld-tools" without saying where to get it.

## Scope

Documentation, plus the wording of one log message. No behaviour change.

- `doc/mission-maker/GUIDE.md` + `.en.md`: a row in the prerequisites table, and a "getting
  the tool" block in the CTLD section covering the releases page, the asset name, the
  pre-release trap, how to read the shipped CTLD version, and the Windows "Unblock" step.
- `src/python/veaf-tools/veaf_libs/locales/{fr,en}.json`: `builder.ctld_no_config` gains the
  releases URL.
- Version bump + both agent manifests, `CHANGELOG.md`.

Deliberately **not** in scope: hard-coding `2.0.0-rc7` into a documentation page. The pinned
version lives in `vendored.yaml` and moves; the page teaches the reader where to read it
instead.

## Definition of done

- Both language versions carry the same information, `poetry run docs-check` green.
- A reader who has never installed CTLD can go from the guide to the downloaded executable
  without guessing.
- No mypy `ignore_errors` entry is reopened (no worker logic touched).
