# 02 — `convert-other` accepts a release `.zip`

Status: ✅ done
Type: feat

## Why

Lekaa's release assets are zips (`Foothold_CA_4.4.1_….zip`) bundling the `.miz` with the
Config Manager executable, the manual and a shortcut. Today `convert-other` requires the
`.miz`, so every adoption *and* every `--update` starts with a manual unzip into a temp
folder — a step that is easy to get wrong (grabbing the previous version's `.miz`) and adds
nothing.

Since the moulinette is meant to be re-run by any VEAF member on each upstream version
(see `doc/mission-maker/FOOTHOLD.md`), the input should be the artefact they downloaded.

## Behaviour

`convert-other <archive.zip> <folder> [--profile …] [--update]`:

- extract to a temp directory, locate the `.miz` members, and adopt the single one found;
- **more than one `.miz`** → fail with a message listing them (no guessing which mission the
  user meant);
- **no `.miz`** → fail with a clear message;
- ignore everything else in the archive (`.exe`, `.pdf`, `.url`) — we never run the
  Config Manager, and nothing outside the `.miz` belongs in a mission folder;
- clean the temp directory afterwards, on success and on failure;
- a `.miz` argument keeps working exactly as today.

## Tasks

- [x] Extract the input resolution out of `veaf_tools/commands/convert_other.py` into a
      small helper (a context manager yielding the `.miz` path) so both the command and the
      tests use one code path.
- [x] Accept `.zip` in the command; keep `.miz` untouched.
- [x] i18n strings (FR + EN) for the two failure cases and for an action line stating which
      `.miz` was picked out of the archive.
- [x] Unit tests: single-`.miz` zip adopts; multi-`.miz` zip fails with both names listed;
      `.miz`-free zip fails; a plain `.miz` path still works; the temp dir is gone
      afterwards in every case.
- [x] End-to-end check against the real
      `Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip`.
- [x] Update `doc/mission-maker/CONVERT_OTHER.md` + `.en.md` (the argument accepts both).
- [x] CHANGELOG + version bump.

## Notes

Windows path length is a live constraint here (see the archived `FIX-LONG-FILENAMES-WINDOWS`
lot) and Foothold's asset names are long. Extract to a **short** temp path rather than one
derived from the archive name.

Fetching the release straight from GitHub (`--from-release`) is deliberately left out: it
adds a network dependency and an auth surface to a command that has neither, and the
download is one click. Revisit only if the manual download turns out to be the friction.
