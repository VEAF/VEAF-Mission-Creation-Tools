# 01 — Generic VEAF alias catalog (tactical / flights)

Status: ⬜ ready
Type: feat

## Context

Flight and tactical channels (Guard, Magic, Archer, Nickel, Texaco-1, Shell-1…) are
**VEAF conventions**, not DCS data — they must be maintained by VEAF. Today they live
inline in the shipped default `presets.yaml` `channels_collection`
(`tactical`/`flights` groups). Lot 3 needs them as a reusable catalog keyed for
reverse-lookup.

## Tasks

- [ ] Extract / define the generic VEAF alias catalog (tactical + flights) as
      maintained data, reusing the values already in the default `presets.yaml`
      (Guard 243/121.5, Archer vhf 120 / uhf 390, Texaco-1 uhf 290.1, …).
- [ ] Build a reverse index `(band, freq) → alias` from it (plus a forward
      `alias → {band: freq}` for emission), with a clear precedence when two aliases
      share a frequency.
- [ ] Unit tests: a few known lookups (Guard/uhf → Guard, 390/uhf → Archer…).

## Definition of Done

- Catalog + reverse index available to the converter; unit-tested.
- No behaviour change yet (data + lookup only); `ruff`/`mypy`/`pytest` green.
