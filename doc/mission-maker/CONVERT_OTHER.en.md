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

## Partial config override

A third-party mission like Foothold ships a large, author-controlled config file
that VEAF leaves **untouched**. To change a handful of settings at deploy time
(difficulty, start side, auto-restart…) without rewriting that file, fill the
`config_override:` block the scaffold leaves commented:

```yaml
config_override:
  target: "Foothold Config.lua"   # the upstream config script you layer on top of
  values:
    CapDifficulty: medium         # global = value
    StartNormal: true
    AutoRestart: false
    Some.Nested.Global: 42        # dotted path → Some.Nested.Global = 42
```

At build, this renders a small `veaf-config-override.lua` that **restates only the
globals you changed**, loaded **between** the untouched upstream config and the
setup script (so the upstream config drops in unchanged on a new Lekaa version,
and your overrides win). Values are passed through as-is — VEAF never interprets
them; the mission validates its own values at runtime.

Each override key is **validated lexically**: every dotted segment must appear as
an identifier somewhere in the injected scripts (`src/scripts/*.lua`). A segment
found nowhere — a typo or a global the upstream renamed/removed — **fails
`veaf-tools validate` and the build**, so silent upstream drift becomes a
build-time alert. (No Lua is executed: the check is a pure-Python whole-word
search.)

## After conversion

- Review `mission.yaml`: enable the VEAF modules you want, check the
  `custom_scripts` order and dependencies.
- Build and test the mission in DCS to confirm iso-functional behaviour.

## Updating to a newer upstream `.miz` (`--update`)

When the third-party author ships a new version (e.g. a Lekaa Foothold bump),
re-import it into your already-adopted folder with `--update`:

```bash
veaf-tools convert-other <new-upstream.miz> <output-folder> --profile foothold --update
```

In update mode `convert-other`:

- **refreshes the third-party scripts** (`src/scripts/*.lua`) and the **mission
  base** (`src/mission/**`) from the fresh `.miz` — overwriting the previous
  copies instead of keeping the old ones (a first-time adoption keeps existing
  files; `--update` is the explicit "take the new version" switch);
- **re-applies versioned-name normalisation** so `custom_scripts:` paths stay
  stable across versions (e.g. `Moose_<new-date>.lua` → `Moose.lua`);
- **preserves your tuned `mission.yaml`** — it is never regenerated, so your
  modules, `config_override`, and `custom_scripts` edits survive;
- **reports the scripts added, updated, and removed upstream** in the conversion
  report, so you can adjust `custom_scripts:` (and `strip_native_triggers:`) for
  any new or vanished script. A script removed upstream is reported but left on
  disk — drop it from `custom_scripts:` yourself if it is no longer needed.

Review the report, reconcile `custom_scripts:` / `strip_native_triggers:` with
any added/removed scripts, then rebuild and test in DCS.
