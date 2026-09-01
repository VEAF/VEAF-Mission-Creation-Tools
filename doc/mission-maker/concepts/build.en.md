# The build

## What it is {#what-it-is}

One command that recomposes the `.miz` from the mission folder. It always does the same four things,
then runs the optional steps whose file it finds.

> **The `.\` is required.** The default Windows terminal is PowerShell, which does not search the
> current directory — on purpose. `cmd.exe` accepts both forms, so `.\` works everywhere. See
> [PowerShell or Command Prompt?](../GUIDE.en.md#powershell-vs-cmd).

```powershell
.\veaf-tools.exe build My-Mission.miz
```

1. reads `src/mission/` (the exploded DCS mission);
2. generates `src/scripts/veaf-config.lua` from `mission.yaml`;
3. **strips the existing VEAF triggers**, then injects fresh ones that load the VEAF scripts and
   yours at start-up;
4. writes the `.miz`.

You **never** add a VEAF trigger by hand in the DCS editor. And because step 3 cleans before it
injects, rebuilding ten times in a row produces the same result ten times.

## The pipeline steps {#pipeline-steps}

Each runs **if its file is present**, in this order:

| Step | File | Card |
|---|---|---|
| `presets` | `src/presets.yaml` | [radio presets](radio-presets.en.md) |
| `spawnable_aircrafts` | `src/spawnables.yaml` | [spawnable groups](spawnables.en.md) |
| `dynamic_slot_templates` | `src/dynamic-slot-templates.yaml` | [dynamic slots](dynamic-slots.en.md) |
| `waypoints` | `src/waypoints.yaml` | — |
| `warehouses` | `src/warehouses.yaml` | [dynamic slots](dynamic-slots.en.md) |
| `spawn_data` | `src/spawn-groups.yaml` | — |
| `weather` | `src/versions.yaml` | [weather variants](weather-variants.en.md) |

To switch one off:

```yaml
pipeline:
  weather: false
```

## Checking before building {#validate}

```powershell
.\veaf-tools.exe validate
```

It rereads the configuration and the mission together, and reports what will not line up — a combat
zone whose trigger zone does not exist, radio presets with no player aircraft to apply them to. It
exits non-zero on an error; `--strict` also makes it exit on a plain warning.

## The output file name {#output-name}

| What you type | What you get |
|---|---|
| `build My-Mission.miz` | `My-Mission.miz` |
| `build My-Mission` (no `.miz`) | `My-Mission_YYYYMMDD.miz` — today's date is appended |
| `build` (nothing) | the name comes from `mission.name` in `mission.yaml` |

## The gotcha {#gotcha}

**A freshly created folder produces *two* files.** `src/versions.yaml` ships with a "noon" variant,
so the weather step runs and additionally writes `missions/My-Mission_noon.miz`. The file at the root
is the base mission; the one under `missions/` is the variant. See
[weather variants](weather-variants.en.md).

## Going further {#more}

- [Pipeline reference](../../PIPELINE_REFERENCE.en.md) — every step in detail
- [`mission.yaml` reference — `pipeline:`](../../MISSION_YAML_REFERENCE.en.md#pipeline) and [`profiles:`](../../MISSION_YAML_REFERENCE.en.md#profiles)
- [CLI reference — `build`](../../CLI_REFERENCE.en.md#build) and [`validate`](../../CLI_REFERENCE.en.md#validate)
- [Full guide — what the builder does](../GUIDE.en.md)
