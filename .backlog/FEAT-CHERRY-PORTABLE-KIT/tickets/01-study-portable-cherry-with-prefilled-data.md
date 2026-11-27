# 01 — Study a portable Cherry Studio with prefilled data

Status: ⬜ ready
Type: study
Files: none (a report)

Find out, from the source and the release assets of `CherryHQ/cherry-studio` (tag `v2.2.3` and later), without assuming:
- Is there a portable build, how does it choose `<exe folder>\data`, and does it ignore a `%APPDATA%\CherryStudio` that exists?
- Can a data folder prepared on one PC (database with the two assistants, the `veaf` server, the knowledge base, the provider settings) open on another? What is bound to the machine (absolute paths, keys, file locations of the knowledge base)?
- Licence (AGPL-3.0): what shipping the executable in the kit requires, and whether linking to the official download is simpler.
- Updates: what an update of the portable build does to the data folder.
- The path to `veaf-tools.exe` (the kit's convention is `C:\VEAF\`): does `ai-setup` still fix it, and does the lockfile guard still apply?
Deliverable: a verdict feasible / risky / no, a table of what is proved (file and line, or a command run) and what is not, and the mechanism if feasible. Read-only on David's installation; copies only, in a scratchpad.
