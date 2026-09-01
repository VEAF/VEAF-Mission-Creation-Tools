# 01 — Say where to get `ctld-tools`, and which one to take

Status: ✅ done

Type: docs · Files: `doc/mission-maker/GUIDE.md` + `.en.md`

## What was missing

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

## What ships

A `#### Où récupérer ctld-tools {#getting-ctld-tools}` / `#### Where to get ctld-tools` block in
the CTLD section of both guides, plus a `ctld-tools.exe` row in the prerequisites table linking to
that anchor, and links to it from the YAML reference and the migration guide.

The anchor is explicit and identical in both languages, per the repository's documentation rule —
the heading text stays in the page's language.

## Do not hard-code the pinned version

The example quotes the header the reader will find, with a note that **their** line is what counts.
The pin itself lives in `vendored.yaml` and moves; the page teaches where to read it.

## Definition of done

- [x] Download location, asset name, and the pre-release trap stated in both languages
- [x] Prerequisites row, linking to `{#getting-ctld-tools}`
- [x] How to read the shipped CTLD version, from the file a mission maker actually has
- [x] Windows "Unblock" step
- [x] `poetry run docs-check` green
