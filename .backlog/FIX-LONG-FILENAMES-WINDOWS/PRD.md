# Lot FIX-LONG-FILENAMES-WINDOWS — long fixture filenames break the Windows marketplace clone

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/long-filenames-windows` → PR → `feature/mcp-mission-editor`

## Context

Testing the plugin in a clean Windows VM (Windows Sandbox), `claude plugin marketplace add` cloned
the repo but the **checkout failed**: `error: unable to create file … KNEEBOARD/…/this folder
contains the images (jpg) … : Filename too long`. Windows' default `MAX_PATH` is 260 chars; the
marketplace clones the **whole repo** into a deep path
(`…\.claude\plugins\marketplaces\VEAF-VEAF-Mission-Creation-Tools\…`), and the fixture placeholders'
95-char names pushed the total over the limit. Result: incomplete working tree → the plugin isn't
found → install fails. This hits **any** maker on Windows without `core.longpaths`.

## Change

- Renamed **42 empty placeholder files** `test/veaf-tools/{mission-builder,demo-mission}/src/mission/
  KNEEBOARD/**/IMAGES/this folder contains the images …` → `.gitkeep`. They were 0-byte markers that
  only keep the (otherwise git-ignored) empty `IMAGES/` folders; no code/test references them
  (kneeboard tests use their own `presets*.png` fixtures). Folders are preserved; `.gitkeep` is a
  short, non-`.jpg`/`.png` name so the kneeboard image handling ignores it exactly as before.
  Longest tracked path drops from ~165 to 91 chars.
- `doc/mission-maker/AI_ASSISTANT_INSTALL.md` (FR + EN): install steps now include
  `git config --global core.longpaths true` (belt-and-braces) and note the partial-clone cleanup +
  the HTTPS-vs-SSH host-key fallback on a fresh machine.

Fixture data + docs only — no product code, no behaviour change.

## Out of Scope

- The marketplace cloning the whole repo (incl. `test/`) is a Claude Code plugin mechanic, not ours;
  keeping every tracked path short is the pragmatic guard.
