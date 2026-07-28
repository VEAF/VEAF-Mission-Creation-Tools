# 01 — Version the Foothold batch script under `tools/`

Status: ✅ done
Type: chore

## Why

A Lekaa release ships one archive per map — ten of them. Adopting a release by hand means ten
`convert-other` runs, each needing the right profile (`foothold` vs `foothold-ww2`). The script
written for the 4.4.1 adoption does the batch in one pass and will be needed at every release,
so it belongs in the repo rather than in a scratch folder.

## What it does

`tools/Convert-FootholdBatch.ps1`, one mission subfolder per archive, named after the archive:

- **picks the profile per mission by content**, not by filename: it opens the `.zip`, then the
  `.miz` inside it (a zip within a zip), and looks for `Foothold Config WW2.lua`. A future
  WWII map named differently still resolves; the archive name is only a fallback when the
  archive cannot be read;
- **never lets one failure stop the batch** — every archive is attempted, a summary table
  closes the run, and the exit code is non-zero if anything failed (usable from a scheduler);
- prints `veaf-tools` output **only on failure**, so ten conversions stay readable;
- `-Update` for every release after the first (refresh scripts, keep each tuned
  `mission.yaml`), `-Validate` to check the whole batch;
- warns when an output path exceeds 180 characters — Foothold's archive names are long and the
  build can hit the Windows limit.

## Tasks

- [x] Add `tools/Convert-FootholdBatch.ps1` with comment-based help (`Get-Help … -Full`).
- [x] Make `-InputFolder` mandatory: the scratch version defaulted to the script's own folder,
      which only made sense while the script sat next to the archives.
- [x] Look for `veaf-tools.exe` in the output folder, then the input folder, then the PATH
      (the output folder is where the updater and `publish-local` drop it).
- [x] Add `tools/README.md` stating what belongs in `tools/` versus the shipped product.
- [x] Reference the script from `FOOTHOLD.md` / `.en.md` as the batch path.
- [x] Exercise it on the real 4.4.1 release: **10/10 adopted and validated**, profile correct
      on every map (`foothold-ww2` only on Normandy).
- [x] CHANGELOG.

## Notes

Deliberately **not** a `veaf-tools` subcommand. A mission-maker receives the executable, not
the repo, so a repo-only script is the wrong shape for them — but batch-adopting ten maps is a
VEAF-internal chore, done by whoever maintains the Foothold missions from a clone. If it ever
needs to reach mission-makers, promoting it to a subcommand is the move, not shipping a `.ps1`.
