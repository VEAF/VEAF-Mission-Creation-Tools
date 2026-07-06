# FIX-VEAF-BUILD-RADIO-LAYOUT-DATA

Status: ✅ done

## Problem

FIX-PYINSTALLER-RADIO-LAYOUT-DATA (previous lot) added `dcs-radio-layouts.yaml` to the
`datas` list in the root `veaf-tools.spec`. After merging and rebuilding, David hit the
exact same `convert-v5` error:

```
Préréglages radio : conversion échouée — [Errno 2] No such file or directory:
'..._MEI.../presets_injector\data\dcs-radio-layouts.yaml'.
```

Root cause of the miss: `veaf-tools.spec` at the repo root is **dead** — it is not
referenced by the real build pipeline (`.github/workflows`, `pyproject.toml` scripts,
or any Python source). The actual `poetry run veaf-build build` command runs
`veaf_build/worker.py`, which invokes PyInstaller programmatically via
`_build_pyinstaller_executable()`, with its own hardcoded `--add-data` list assembled
by `_veaf_tools_extra_data()`. That method already bundled `dcs-radio-specs.yaml`
(`veaf_build/worker.py:452-454`) but never gained a matching entry for
`dcs-radio-layouts.yaml` when FEAT-RADIO-PRESET-PROJECTION introduced it.

## Fix

Add a `dcs-radio-layouts.yaml` entry to `_veaf_tools_extra_data()`, mirroring the
existing `dcs-radio-specs.yaml` one. Added a regression test
(`test_veaf_tools_extra_data_bundles_both_radio_yaml_files`) asserting both YAML
files are present in the assembled extra-data list, so a future third data file
added under `presets_injector/data` without updating this method fails CI instead
of only surfacing in a packaged `.exe` months later.

## Out of scope

- The root `veaf-tools.spec` is left as-is (already fixed by the previous lot, still
  harmless even though unused) — removing dead files is a separate call for David to make.
