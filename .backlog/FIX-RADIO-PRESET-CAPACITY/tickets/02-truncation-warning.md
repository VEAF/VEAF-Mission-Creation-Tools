# 02 — A capacity truncation warns at build

Status: ⬜ ready

## Done when

- `_truncate_to_capacity` logs at **warning** level, through `veaf_libs.logger`, a message (fr and en locales) naming the unit type, the radio, the capacity and the number of dropped entries (PRD D3); one warning per radio and per run, not per unit.
- A test asserts the warning on a truncation and its absence within capacity.
- A build with the shipped defaults raises no such warning (measured, said in the PR).
- ADR 0010 and the `capacity` comment in `dcs-radio-layouts.yaml` say truncation now warns, and why.
