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

## What it does

1. **Extracts** the `.miz` into the mission folder (scripts land in
   `src/scripts/`). The third-party copies of known community scripts (CTLD,
   CSAR, AIEN…) are **kept** as-is (iso-functional) rather than replaced by the
   VEAF versions.
2. **Detects** the scripts loaded by the mission's native triggers, in their
   **load order** (trigger order × action order).
3. **Generates** a scaffold `mission.yaml`:
   - an **ordered** `custom_scripts:` block (the original load order);
   - a `strip_native_triggers:` list of the detected native loader triggers —
     the **build** will strip them (a later lot) to avoid double loading;
     `convert-other` only records them;
   - every VEAF module **disabled**: enable what the mission needs.
4. **Emits** a Markdown report summarising the actions and review items.

## After conversion

- Review `mission.yaml`: enable the VEAF modules you want, check the
  `custom_scripts` order and dependencies.
- Build and test the mission in DCS to confirm iso-functional behaviour.
