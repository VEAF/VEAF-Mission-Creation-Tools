# 04 — Per-type kneeboards + Viggen pilot labels

Status: ✅ done
Depends on: 02, 03

## Scope

Replace the collection-driven generic-folder generation with per-type pages:

- Collect the presets actually injected, keyed `(coalition, concrete unit_type)`
  during `process_groups` (works for packer, legacy assignments, `all`/regex;
  `none` skipped).
- Emit one PNG per entry to `KNEEBOARD/<type>/IMAGES/presets.png`; suffix
  `-<coalition>` only when the same type is injected for both coalitions.
- Stop emitting the generic `KNEEBOARD/IMAGES/presets-<name>.png` pages.
- Title = concrete type (+ coalition). Sanitise types containing `/` for the path.
- **Viggen labels**: the AJS-37 CH column shows pilot-facing labels — `100`–`139`
  for the 40 data slots, `Sp1/Sp2/Sp3/E/F/G/H` for slots 41–47 — driven by the
  layout, instead of raw slot indices. Other types keep index = number.
- A radio with many channels (Viggen's 47) is split across columns for legibility.

## Acceptance

- A mission with a blue AJS37 and a blue A-10C produces
  `KNEEBOARD/AJS37/IMAGES/presets.png` and `KNEEBOARD/A-10C/IMAGES/presets.png`,
  and no `KNEEBOARD/IMAGES/presets-*.png`.
- Blue + red of the same type → `presets-blue.png` / `presets-red.png` in that
  type's folder.
- The AJS37 page shows `104` (not `05`) and `Sp1`/`H`, wrapped across columns.

## Tests

- `test_presets_injector_worker*`: per-type file paths, coalition suffixing,
  generic-folder removal, Viggen label mapping.
