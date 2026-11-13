# FEAT-SIGNED-RELEASES — Sign the Windows executables of every release with SignPath

Status: 🚫 wontfix

Dropped by David on 2026-11-13, after the audit ("on laisse tomber"): the DCS-derived data bundled in `veaf-tools.exe` makes SignPath acceptance uncertain, and the other routes (moving that data out of the executable, a paid certificate) were not worth their cost.

Asked by David (Obsidian T340, 2026-10-19); explored and agreed on 2026-11-13 ("crée le lot et lance l'audit").

## Why

`veaf-tools.exe`, `veaf-tools-updater.exe` and `veaf-logs.exe` ship unsigned: Windows warns at first launch, and a mission maker downloading the tools for the first time meets a "Windows protected your PC" screen.
SignPath Foundation signs open-source projects for free.

## What SignPath asks — read on https://signpath.org/terms, 2026-11-13 (page marked "Draft")

- OSI-approved license with no commercial dual-licensing, **for all components**; no proprietary code (system libraries allowed); no malware, no PUP, no hacking tools.
- Actively maintained, already released in the form to be signed; functionality documented on the download page.
- Privacy: any data collection disclosed in a privacy policy, or the statement that the program sends nothing to other networked systems unless the user asks.
- MFA for every team member, on SignPath and on GitHub; declared roles — authors, reviewers (every non-committer change reviewed), approvers (each signing request approved).
- Binaries built from source in a verifiable way, by an automated build whose origin SignPath checks; **each release approved by hand**.
- Product-name metadata = the project's name, product version consistent across the build.
- A "Code signing policy" section on the home page and the release pages, with the sentence "Free code signing provided by SignPath.io, certificate by SignPath Foundation", the roles and the privacy statement.
- The certificate's publisher is **SignPath Foundation**, not VEAF.
- Acceptance is discretionary, with no appeal; no delay stated.

## What we already have

- Apache 2.0 license (`LICENSE`).
- Windows executables built by GitHub Actions on `windows-latest` (`.github/workflows/release.yml`): `veaf-tools.exe` and `veaf-tools-updater.exe` (PyInstaller, `veaf-build`), `veaf-logs.exe`; plus `published.zip` and the map capture kit, which bundles `dcs-serve.exe` from `VEAF/VEAF-dcs-bridge`.

## Out of scope

- `published.zip` and the map capture kit as archives (a zip cannot be Authenticode-signed; the executables inside can).
- Linux and macOS binaries (macOS notarisation is a separate programme).

## Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Apply before or after a license audit | **After.** "No proprietary code, for all components" is the condition most likely to stop us (vendored Lua scripts, DCS-derived data inside the executable); ticket 01 answers it before David applies |
| D2 | If the audit finds a blocker | Decide then between removing or replacing the component, dropping SignPath for a paid certificate in VEAF's own name, or not signing; written up from the audit's findings |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [License and content audit of what the executables bundle](tickets/01-license-audit.md) | ✅ |
| 02 | [Apply to SignPath Foundation (David)](tickets/02-apply.md) | 🚫 |
| 03 | [Sign in the release workflow, publish the code signing policy](tickets/03-sign-in-release.md) | 🚫 |

## Outcome of ticket 01 — 2026-11-13

[audit.md](audit.md): not as is.
Every code component of the three executables is under an OSI license; `veaf-logs.exe` and the updater are clean.
The obstacle is the DCS-derived reference data bundled in `veaf-tools.exe` (F1), under no license: data rather than code, so only SignPath can say whether it blocks.
Cheap fixes worth doing whatever happens: WMM files re-sourced from NOAA (F2), version resource on `veaf-logs.exe` (F4), third-party notices shipped (F7), a license on VEAF-dcs-bridge (F9).
Next: ask SignPath about F1 and the DejaVu font (F5) before applying.
