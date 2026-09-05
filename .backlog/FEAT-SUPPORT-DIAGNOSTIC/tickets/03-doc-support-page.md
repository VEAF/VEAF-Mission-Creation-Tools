# 03 — The documentation points at the log that exists

Status: ✅ done

Type: docs

## The problem

Two defects, one small and one structural.

**The path is wrong.** [`doc/TOOLS_REFERENCE.md:626`](../../../doc/TOOLS_REFERENCE.md) and `:816`
(and their `.en.md` twins) tell the user to look for `veaf-tools.log` *in the current directory*.
It is written to `~/.veaf/veaf-tools.log`, through `get_veaf_home()`. Someone following the page
finds nothing and concludes there is no log.

**There is no page about getting help.** The subject is scattered across three places, none of them
saying what to provide:

| Where | What it says |
|---|---|
| [`doc/index.md:96`](../../../doc/index.md) | three links — Discord, GitHub issues, the VEAF site |
| [`doc/pilot/GUIDE.md:387`](../../../doc/pilot/GUIDE.md) | the same links again |
| [`doc/TOOLS_REFERENCE.md:810`](../../../doc/TOOLS_REFERENCE.md) | a real procedure, but only for `veaf-tools-updater.exe` |

`SECURITY.md` is the only file in the repository that says what a report should contain — and it
covers vulnerabilities only.

The debug-logging section of [`doc/mission-maker/GUIDE.md:993`](../../../doc/mission-maker/GUIDE.md)
explains where the DCS log lives and how to raise the log level, but never says to attach it to a
report.

## What to write

A support page, in both languages and in the `nav`, that answers one question: *something is wrong,
what do I do?* It routes to the right place (Discord for a question, an issue for a defect, the
security channel for a vulnerability), tells the reader to run `doctor` and paste its block, and
says where both logs live — the tool's and DCS's.

This is also the page the Discord bot will link to, so it must exist before
[`FEAT-SUPPORT-DISCORD-QA`](../../FEAT-SUPPORT-DISCORD-QA/PRD.md).

## Notes

- Explicit English anchors on any section linked from elsewhere — `## Obtenir de l'aide {#support}`
  / `## Getting help {#support}`.
- Command examples in PowerShell, always written `.\veaf-tools.exe`.
- No hand-written version numbers.

## Definition of done

- [x] The two wrong log paths in `TOOLS_REFERENCE` corrected, FR and EN
- [x] A support page shipped as `page.md` **and** `page.en.md`, both in the `mkdocs.yml` `nav` with
      their `nav_translations` entry
- [x] It covers: which channel for what, `doctor`, where the two logs are, what to attach
- [x] Linked from `doc/index.md` and from the pilot guide, both languages
- [x] `poetry run docs-check` passes
