---
Status: ✅ done · archived 2026-09-28
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
- `CHANGELOG.md`.

**Correction, 2026-09-01:** this line originally read "Version bump + both agent manifests". It no
longer applies — `CLAUDE.md` §9.5 forbids a PR from moving `pyproject.toml` or either plugin
manifest, since two concurrent PRs then conflict by construction on files carrying no engineering
content. A release commit moves all three together.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Say where to get `ctld-tools`, and which one to take](DOC-CTLD-TOOLS-DOWNLOAD.md) | ✅ |
| 02 | [The builder's own message must not dead-end](DOC-CTLD-TOOLS-DOWNLOAD.md) | ✅ |
| 03 | ["The most recent one is at the top" points at a build that is not a release](DOC-CTLD-TOOLS-DOWNLOAD.md) | ✅ |

Deliberately **not** in scope: hard-coding `2.0.0-rc7` into a documentation page. The pinned
version lives in `vendored.yaml` and moves; the page teaches the reader where to read it
instead.

## Definition of done

- [x] Both language versions carry the same information, `poetry run docs-check` green.
- [x] A reader who has never installed CTLD can go from the guide to the downloaded executable
      without guessing.
- [x] No mypy `ignore_errors` entry is reopened (no worker logic touched).

## Closing note — the premises re-measured, and the one sentence that did not survive

The four gaps above were measured on 2026-08-25 and closed by tickets 01 and 02. Closing the lot
meant re-checking those premises against `VEAF/CTLD` rather than trusting the measurement, because
the whole download procedure rests on them. Measured **2026-09-01**:

| Premise | Verdict |
|---|---|
| `ctld-tools.exe` is a release asset of `VEAF/CTLD` | **holds** — 22.5 MB, attached to `published-v2.0.0-rc8` and to the `dev` build |
| **Every** CTLD 2 release is a pre-release, so none is "Latest release" | **holds** — all 9 releases are pre-releases, and `GET /repos/VEAF/CTLD/releases/latest` answers **404** |
| A "CTLD dev build" release exists, newer than the vendored engine | **holds** — tag `dev`, rebuilt 2026-08-26, newer than the pinned `2.0.0-rc7` |
| The shipped version is readable in the installed `CTLD.lua` header | **holds** — `Version : 2.0.0-rc7`, matching `vendored.yaml` |

Two things moved since 2026-08-25, neither of them invalidating the block:

- the newest release is now `published-v2.0.0-rc8` (2026-08-26), not the rc7 the PRD cites. It is
  **ahead of the pin**, which is precisely the case the version rule exists for: the reader takes
  the one matching their engine, not the newest;
- the `dev` build was republished, and that exposed a defect in our own wording — see ticket 03.
  *"The most recent one is at the top of the list"* points at a rolling build whose body says
  *"This is not a release"*, and it only missed the top spot on 2026-08-26 by three minutes. That
  sentence is gone; the `published-v…` tag is now the discriminator.

`vendored.yaml` is untouched: bumping the CTLD pin to rc8 is the drift watcher's business, not a
documentation lot's.

---

## Tickets, in full

## 01 — Say where to get `ctld-tools`, and which one to take

Status: ✅ done

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`

### What was missing

The CTLD section named `ctld-tools.exe` and linked `https://github.com/VEAF/CTLD`, and stopped
there. Following that link does not reach the file: the executable is a **release asset**, and
every CTLD 2 release is a *pre-release*, so the repository landing page shows no "Latest release"
at all. The reader is left on a page with no download on it.

Three more things had to be said in the same place:

- the **prerequisites table** lists VS Code but not `ctld-tools.exe` — a reader planning their
  toolchain never learns they need it;
- **which version to take.** The tool and the engine move together, so the reader has to pick the
  release matching the CTLD version their VEAF MCT ships — and no page said where that version is
  written (the header of `published/src/scripts/community/CTLD.lua`);
- the Windows **"Unblock"** step, same as for `veaf-tools-updater.exe`.

### What ships

A `#### Où récupérer ctld-tools {#getting-ctld-tools}` / `#### Where to get ctld-tools` block in
the CTLD section of both guides, plus a `ctld-tools.exe` row in the prerequisites table linking to
that anchor, and links to it from the YAML reference and the migration guide.

The anchor is explicit and identical in both languages, per the repository's documentation rule —
the heading text stays in the page's language.

### Do not hard-code the pinned version

The example quotes the header the reader will find, with a note that **their** line is what counts.
The pin itself lives in `vendored.yaml` and moves; the page teaches where to read it.

### Definition of done

- [x] Download location, asset name, and the pre-release trap stated in both languages
- [x] Prerequisites row, linking to `{#getting-ctld-tools}`
- [x] How to read the shipped CTLD version, from the file a mission maker actually has
- [x] Windows "Unblock" step
- [x] `poetry run docs-check` green

---

## 02 — The builder's own message must not dead-end

Status: ✅ done

Type: docs · Files: `src/python/veaf-tools/veaf_libs/locales/{fr,en}.json`

### The defect

`builder.ctld_no_config` fires exactly when the reader needs the tool — CTLD enabled, no
`ctld-config.yaml` in the mission folder — and told them to "create one with ctld-tools" without
saying where to get it. The one message guaranteed to reach a reader who has not installed the tool
was the one that did not say where it lives.

### What ships

Both locales carry the releases URL **and** the pre-release trap in one sentence, because the URL
alone lands on a page whose landing view shows nothing:

> Create one with ctld-tools.exe, downloadable from https://github.com/VEAF/CTLD/releases
> (CTLD 2 releases are pre-releases: go through the Releases tab).

No behaviour change, no worker logic touched — so no mypy `ignore_errors` entry is reopened.

### Definition of done

- [x] `builder.ctld_no_config` carries the URL in `fr.json` and `en.json`
- [x] Both wordings say the same thing; neither leaves the reader on the landing page

---

## 03 — "The most recent one is at the top" points at a build that is not a release

Status: ✅ done

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`

### Found while re-verifying the lot, not by a report

Closing the lot meant re-checking its premises against `VEAF/CTLD` rather than trusting the
2026-08-25 measurement. Measured **2026-09-01**:

| Claim | Verdict |
|---|---|
| `ctld-tools.exe` is a release asset | holds — 22.5 MB, attached to `published-v2.0.0-rc8` |
| Every CTLD 2 release is a pre-release | holds — all 9 are, and `GET /releases/latest` answers **404** |
| A "CTLD dev build" release exists | holds — tag `dev`, rebuilt 2026-08-26, carries `ctld-tools.exe` |

The download block was written against that list, and one sentence in it does not survive the
check: *"The most recent one is at the top of the list."*

The `dev` tag is a **rolling** release. Its own body says so — *"This is not a release. It is the
tool built from the latest merge into `develop`"* — and it returns to the top of the list every
time it is rebuilt. On 2026-08-26 it missed the top spot by three minutes, purely by accident of
publishing order. Telling a reader to take the top entry therefore points them, sooner or later, at
a build carrying no version number, immediately after telling them to match the version.

### What ships

The warning admonition loses that sentence and gains the discriminator: the `CTLD dev build` entry
is not a release, real releases are tagged `published-v…`, and the version rule below the
admonition is what picks among them.

Nothing else in the block changes — the anchor, the prerequisites row and the version-reading
instruction all still hold.

### Definition of done

- [x] Neither language tells the reader to take the top entry
- [x] The `CTLD dev build` entry is named, and said not to be a release
- [x] `poetry run docs-check` green

---
