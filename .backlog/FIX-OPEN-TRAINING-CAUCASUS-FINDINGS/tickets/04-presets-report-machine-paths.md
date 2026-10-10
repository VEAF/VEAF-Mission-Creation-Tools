# 04 — The presets report a mission commits names no machine path

Status: ⬜ ready

Files: `presets_injector/presets_injector_worker.py` (`generate_validation_report`), its translations, tests.

## What happened

`mission build` writes `presets-validation-report.md` into the mission folder (`veaf_tools/commands/build.py:393`), and the Open Training missions commit it.
Its header carries the build date and two absolute paths (`presets_injector_worker.py:474-476` on `develop` 10b53bb6): the presets file and the built `.miz`.
Recompiling GermanyCW-v6 in a worktree on 2026-10-10 changed those three lines to `D:\dev\…\.claude\worktrees\objective-tharp-510609\…` and today's date, with no finding changed: every build on another machine, another worktree or another day dirties the file, and a reviewer reads a worktree path in a committed document.

## Done when

- The report names the presets file and the mission relative to the mission folder (`src/presets.yaml`, the `.miz` file name), and keeps an absolute path only for a file outside it.
- Two builds of the same mission from two folders on different days write the same report, byte for byte, when the findings are the same.
- Tests: a file inside the mission folder is written relative, one outside stays absolute.
