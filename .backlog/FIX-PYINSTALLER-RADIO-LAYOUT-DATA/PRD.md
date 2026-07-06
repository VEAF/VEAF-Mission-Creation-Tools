# FIX-PYINSTALLER-RADIO-LAYOUT-DATA

Status: ✅ done

## Problem

Running the packaged `veaf-tools.exe` (built via PyInstaller from `veaf-tools.spec`),
`convert-v5` failed to convert radio presets:

```
Préréglages radio : conversion échouée — [Errno 2] No such file or directory:
'...\_MEI.../presets_injector\data\dcs-radio-layouts.yaml'.
```

The source checkout worked fine — only the built `.exe` was affected. `dcs-radio-layouts.yaml`
was added by FEAT-RADIO-PRESET-PROJECTION alongside the pre-existing `dcs-radio-specs.yaml`,
but `veaf-tools.spec`'s `datas` list was never updated to bundle it, so PyInstaller never
copied it into the packaged app.

## Fix

Add the missing `datas` entry to `veaf-tools.spec`, mirroring the existing
`dcs-radio-specs.yaml` entry:

```python
('src\\python\\veaf-tools\\presets_injector\\data\\dcs-radio-layouts.yaml', 'presets_injector\\data'),
```

## Out of scope

- No code/behavior change — pure packaging fix. No new unit test (nothing to unit-test:
  PyInstaller `datas` bundling can only be verified via an actual build).
