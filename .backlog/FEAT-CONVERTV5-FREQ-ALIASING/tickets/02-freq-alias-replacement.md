# 02 — Theatre-aware freq→alias replacement in convert-v5 output

Status: ⬜ ready
Type: feat

## Context

The core of the lot: turn raw frequencies in the converted presets into readable
aliases, using the VEAF catalog (ticket 01) + the theatre's airfields (lot 2,
`airfield-frequencies.yaml`).

## Tasks (TDD)

- [ ] Detect the theatre from the `.miz` (`theatre`); load the theatre's airfield
      frequencies (lot 2) and merge with the generic VEAF catalog (ticket 01) into one
      reverse index `(band, freq) → alias`.
- [ ] For each channel frequency in the converted presets, reverse-lookup by
      `freq + band`; on a match, replace the raw frequency with the alias reference.
      **Unmatched frequency → left hardcoded** (test this explicitly).
- [ ] Insert the resolved catalog (`channels_collection`) into **both** `presets.yaml`
      and `presets.v5.yaml` so the aliases resolve at build time.
- [ ] Specials/fusions: option (a) — packer best-effort, no override.
- [ ] Failing tests first: a converted preset with a Gudauta-matching freq becomes
      `Gudauta`; an Archer-matching freq becomes `Archer`; an off-catalog freq stays raw.

## Definition of Done

- Converted `presets.yaml`/`presets.v5.yaml` carry aliases where matched, raw
  frequencies otherwise; catalog embedded so the build resolves them.
- Round-trip: the aliased output still builds to the same channels as before aliasing.
- `ruff`/`mypy`/`pytest` green; coverage gate respected; doc updated (convert-v5 /
  presets reference) if user-facing output changes.
