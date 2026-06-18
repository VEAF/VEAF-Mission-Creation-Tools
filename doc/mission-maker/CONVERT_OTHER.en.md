# `convert-other` — adopt a third-party mission onto v6

`convert-other` adopts a **third-party** `.miz` mission (non-VEAF, e.g. *Foothold*
by Lekaa) onto the v6 toolchain. It is the counterpart of
[`convert-v5`](MIGRATION_GUIDE.en.md), which migrates a **VEAF v5** mission: here
the mission was never built with the VEAF tools, so we **adopt** it.

> This command holds no knowledge specific to any given mission. The
> author-specific knowledge for a mission family (script order, triggers to
> strip, settings to override…) is carried by a *conversion profile* (coming
> next). See ADR 0007.

## Usage

```bash
veaf-tools convert-other <mission.miz> <output-folder>
```

With no argument (in an interactive terminal) the command opens the TUI wizard
and asks for the source `.miz` then the output folder.

| Argument / option | Purpose |
|-------------------|---------|
| `INPUT_MIZ` | Path to the third-party `.miz` to adopt |
| `OUTPUT_FOLDER` | v6 mission folder to create / populate |
| `--force` | Overwrite an existing `mission.yaml` (otherwise left untouched) |
| `--report-file` | Markdown report path (default `<output>/convert-other-report.md`) |
| `--profile` | Conversion profile (bundled name, e.g. `foothold`, or a path to a `.yaml`) |

## Conversion profiles

Without `--profile` the scaffold is generic (the `minimal` tier). With a profile,
mission-family-specific knowledge is applied — **data, not code** (see
[ADR 0007](../../docs/adr/0007-third-party-mission-adoption.md)). The bundled
`foothold` profile:

- **enables the VEAF modules** Foothold uses (RADIO, SPAWN, WEATHER, SHORTCUTS,
  SECURITY, REMOTE) instead of the `minimal` tier;
- **normalises versioned names** (`Moose_2026-04-28.lua` → `Moose.lua`) so
  `custom_scripts:` paths stay stable across Lekaa versions;
- **writes a marker** `conversion_profile: foothold` into `mission.yaml`;
- **scaffolds a commented `config_override`** targeting `Foothold Config.lua`;
- **declares incompatible modules** (`CTLD`: Foothold ships its own). Enabling an
  incompatible module makes **`veaf-tools validate` and the build fail** — including
  if you enable it by hand later.

```bash
veaf-tools convert-other <mission.miz> <output-folder> --profile foothold
```

## What it does

1. **Extracts** the `.miz` into the mission folder (scripts land in
   `src/scripts/`). The third-party copies of known community scripts (CTLD,
   CSAR, AIEN…) are **kept** as-is (iso-functional) rather than replaced by the
   VEAF versions.
2. **Detects** the scripts loaded by the mission's native triggers, in their
   **load order** (trigger order × action order).
3. **Generates** a scaffold `mission.yaml`:
   - an **ordered** `custom_scripts:` block (the original load order);
   - a `strip_native_triggers:` list of the detected native loader triggers (by
     comment or glob pattern) — the **build strips them** (trigrule + `trig`
     entries + `mapResource` resources) so they do not double-load alongside the
     re-injected `custom_scripts`;
   - a `modules:` block seeded with the **`minimal`** tier (infra + MIST +
     RADIO/SPAWN/SHORTCUTS/INTERPRETER, SECURITY commented): a working VEAF
     baseline out of the box; enable more as needed.
4. **Emits** a Markdown report summarising the actions and review items.

## After conversion

- Review `mission.yaml`: enable the VEAF modules you want, check the
  `custom_scripts` order and dependencies.
- Build and test the mission in DCS to confirm iso-functional behaviour.
