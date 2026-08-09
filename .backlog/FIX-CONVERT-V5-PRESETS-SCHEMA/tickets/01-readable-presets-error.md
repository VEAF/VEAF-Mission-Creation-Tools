# 01 — Say what is wrong instead of dying on `.lower()`

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/presets_injector/presets_manager.py`

## The failure as a mission maker sees it

```
Error loading presets from D:\…\src\presets.yaml: 'dict' object has no attribute 'lower'
AttributeError: 'dict' object has no attribute 'lower'
```

No file line, no key, no statement of what was expected. The cause — one extra nesting level in
`presets_assignments` — is nowhere in the message.

## Where

`PresetAssignmentCollection.from_dict` walks three levels deep and assumes the leaf is a string:

```python
for coalition, coalition_data in data.items():
    for aircraft_type, type_data in coalition_data.items():
        for unit_type, preset_definition_name in type_data.items():
            if preset_definition_name.lower() == "none":
```

With a v5-schema file the loop is shifted by one: `coalition` is `"coalitions"`, `aircraft_type`
is `"blue"`, `unit_type` is `"plane"`, and the leaf is `{'all': 'modern_blue'}`.

## Tasks

- [ ] Validate the shape before walking it, and refuse with a message that names **the file, the
      key path, what was found and what was expected**.
- [ ] Recognise the specific case: a top-level `coalitions` key under `presets_assignments` is
      the v5 schema. Say so, and say what to do — that is the difference between a dead end and
      a five-second fix.
- [ ] Same treatment for the sibling leaves in this file that assume a string without checking.
- [ ] Tests: the v5 shape, a leaf that is a list, a leaf that is a number, and the happy path
      unchanged.

## Acceptance criteria

- [ ] No `AttributeError` escapes this loader for any shape of input.
- [ ] The message is written to be read by a mission maker, not by whoever wrote the parser —
      check it by reading it aloud.
