# 02 — One summary warning per build

Status: ✅ done

## Done when

- A build that truncates radios logs **one** warning (fr and en locales) listing each truncated type / radio with capacity and dropped count; the per-radio line moves to debug (PRD D2). Tests: one warning for several truncations, none within capacity.
- A build from the defaults shows a single capacity warning (measured, said in the PR).
- ADR 0010, the `capacity` comment in `dcs-radio-layouts.yaml` and the presets doc page (fr, en) say so; `CHANGELOG.md` entry appended under `[Unreleased]`.
