# `convert-other` — adopt a third-party mission onto v6

`convert-other` adopts a **third-party** `.miz` mission (non-VEAF, e.g. *Foothold*
by Lekaa) onto the v6 toolchain. It is the counterpart of
[`convert-v5`](MIGRATION_GUIDE.en.md), which migrates a **VEAF v5** mission: here
the mission was never built with the VEAF tools, so we **adopt** it.

> This command holds no knowledge specific to any given mission. The
> author-specific knowledge for a mission family (script order, triggers to
> strip, settings to override…) is carried by a *conversion profile*. Two ship
> with the tool: `foothold` and `foothold-ww2`. See ADR 0007.

## Usage

```bash
veaf-tools convert convert-other <mission.miz> <output-folder>
```

With no argument (in an interactive terminal) the command opens the TUI wizard
and asks for the source `.miz` then the output folder.

### The input can be a release archive

Third-party missions are often distributed as a **release `.zip`** rather than a bare
`.miz` — Lekaa's Foothold assets bundle the mission with a config-manager executable, the
manual and a shortcut. Pass the archive you downloaded and `convert-other` adopts the `.miz`
inside it:

```bash
veaf-tools convert convert-other Foothold_CA_4.4.1_Multi_Language_Coldwar-Modern-Vietnam.zip <output-folder> --profile foothold
```

Only the `.miz` member is read; nothing else in the archive is written anywhere (the bundled
executable is never extracted, and never run). The archive must contain **exactly one**
`.miz`: with none, or with several, the command stops and names what it found rather than
guessing which mission you meant.

| Argument / option | Purpose |
|-------------------|---------|
| `INPUT_MIZ` | Path to the third-party mission to adopt: a `.miz`, or a release `.zip` containing exactly one |
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
- **normalises versioned names** (`Moose_2026-06-14.lua` → `Moose.lua`,
  `Splash_Damage_3.4.1_leka.lua` → `Splash_Damage.lua`) so `custom_scripts:` paths stay
  stable across Lekaa versions. The per-map setup script (`MA_Setup_CA.lua`,
  `footholdSyriaSetup.lua`, `kola_setup.lua`…) is **not** normalised: those names vary per
  map, not per version;
- **writes a marker** `conversion_profile: foothold` into `mission.yaml`;
- **scaffolds a commented `config_override`** targeting `Foothold Config.lua`;
- **declares incompatible modules** (`CTLD`: Foothold ships its own). Enabling an
  incompatible module makes **`veaf-tools mission validate` and the build fail** — including
  if you enable it by hand later.

```bash
veaf-tools convert convert-other <mission.miz> <output-folder> --profile foothold
```

### Bundled profiles

| Profile | For |
|---------|-----|
| `foothold` | Lekaa's Foothold on Caucasus, Persian Gulf, Sinai, Syria, Cold War Germany, Kola, Iraq, Afghanistan |
| `foothold-ww2` | WWII Normandy Foothold — a different config file (`Foothold Config WW2.lua`), no `Era`, and no Foothold CTLD, so the VEAF CTLD is *not* incompatible there |

See [FOOTHOLD](FOOTHOLD.en.md) for the full per-version procedure.

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
`veaf-tools mission validate` and the build**, so silent upstream drift becomes a
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
veaf-tools convert convert-other <new-upstream.miz> <output-folder> --profile foothold --update
```

The new upstream can be the release `.zip` here too — same rule, exactly one `.miz` inside.

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
