# 02 — `--update` rewrites `custom_scripts:` to what the release loads

Status: ✅ done

`convert-other --update` used to preserve the `custom_scripts:` list and only reconcile `delay_seconds`.
A script the release renamed stayed listed under its old name, and its successor was never loaded.

Now (`reconcile_custom_scripts` in `mission_builder/other_converter.py`):

- the entries the release loads are written in its load order, a new one with its upstream `delay_seconds`;
- an entry the previous release loaded and this one does not is removed;
- every other entry is the mission maker's: kept, after the upstream ones, in its own order, lines untouched;
- the file is edited as text (comments, quoting, line endings survive), and each change is named in the report.

What the previous release loaded comes from `convert-other-state.yaml`, or, for a mission adopted before that file existed, from the `mapResource` of the exploded base it left (`read_previous_upstream_scripts`), read before the extraction overwrites it.
Measured on the ten VEAF missions on 2026-10-17: every `custom_scripts:` entry was in the old `mapResource`, so none is a maker's script.

The review item asking to remove the stale entries by hand is gone: the converter removes them.

Tests: `TestUpdateReconcilesTheScriptList`, `TestPreviousUpstreamScripts` in `test/python/mission_builder/test_other_converter.py`.
