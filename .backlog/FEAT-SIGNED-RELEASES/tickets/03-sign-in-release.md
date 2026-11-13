# 03 — Sign in the release workflow, publish the code signing policy

Status: 🚫 wontfix

Waits for SignPath's acceptance (ticket 02).

## Done when

- `release.yml` submits the Windows executables to SignPath and uploads the signed ones, before `published.zip` is assembled so the zip carries signed executables; the run waits for the manual approval.
- Product-name and version metadata are set on every executable as SignPath requires.
- The documentation home page and the release notes carry the "Code signing policy" section, the required sentence, the roles and the privacy statement (fr, en; `docs-check` passes).
- A signed release is downloaded and its signature checked on Windows (`Get-AuthenticodeSignature`).
- `CHANGELOG.md` entry under `[Unreleased]`.
