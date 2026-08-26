---
Status: ✅ done
---

# 01 — The `manage_logistics` flag, written into every scaffolded mission

The flag must be **visible in the file**, not merely defaulted in code: a maker who never sees the
key cannot know the behaviour exists, and that invisibility is the whole defect this lot fixes.

## Do

- Read `modules.CTLD.manage_logistics` (default **true**) where the CTLD module config is
  normalised. The short form `CTLD: true` keeps working and means
  `{enabled: true, manage_logistics: true}`.
- **Emit it when scaffolding.** `generate_mission_yaml({"CTLD", …})` currently produces the short
  form — verified by running it: the block is exactly `  CTLD: true`. It must become the expanded
  form, with a comment saying what the flag does:

  ```yaml
    CTLD:
      enabled: true
      manage_logistics: true   # register every carrier and FARP ammo dump as a CTLD loading point
  ```

  The emitting code is the community-scripts loop in
  `veaf_libs/lua_config_generator.py` (the `upper == "CTLD"` branch around line 1892 for the
  commented-out form, and the enabled path that yields `CTLD: true`).
- **Same for the disabled form**, which today reads `# CTLD: false   # configured in
  ctld-config.yaml …`: show the expanded shape so the key is discoverable before CTLD is switched
  on.
- `src/defaults/mission-folder/mission.yaml`: same change, and fix the comment block that currently
  states CTLD "takes only its on/off flag here" — that sentence stops being true.
- `yaml_validator.py`: accept the key, reject a non-boolean with the same shape of message the
  neighbouring `enabled` / `logLevel` checks use. Do **not** touch the `settings:` rejection.

## Watch out

The defaults file is a **lockstep** obligation (CLAUDE.md §9.7): the shipped default must match what
the generator produces, in the same lot. A test already compares the two — keep it green.

## Done when

A mission scaffolded with CTLD enabled contains `manage_logistics: true` in plain sight;
`CTLD: true`, `CTLD: {enabled: true}` and `{enabled: true, manage_logistics: false}` all validate;
`manage_logistics: "yes"` fails with a readable message.
