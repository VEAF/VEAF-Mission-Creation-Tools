---
Status: ✅ done · archived 2026-09-28
---

# FEAT-CTLD-AUTO-LOGISTICS — VEAF stops silently losing the FARPs it used to register

## The defect, as found

Reported from a real mission on 2026-08-26: FARPs placed in the mission editor are not
CTLD loading points. Its `ctld-config.yaml` carries `logisticUnitTypes: []`, and the mission maker
had worked around it by naming ten units `logistic1` … `logistic10` by hand.

Until CTLD 2, `veaf.ctld_initialize_replacement` registered them from a hard-coded list — every
`LHA_Tarawa`, `Stennis`, `CVN_71`, `KUZNECOW` and `FARP Ammo Dump Coating` in the mission became a
logistic point, and every carrier a troop pickup zone. CTLD 2 offers the equivalent as two
configuration lists (`logisticUnitTypes`, `troopZoneShipTypes`) which it ships **empty** — the
right default for the wider world, the wrong one for a VEAF mission.

`veaf-tools mission prepare` fills them at scaffold time
([`VEAF_CONFIG_OVERRIDES`](../../src/python/veaf-tools/veaf_libs/ctld_config.py)), **and only then**.
The file is never rewritten afterwards, not even with `--force`, so every other route to a
`ctld-config.yaml` — written by hand, copied from another mission, regenerated from the CTLD
defaults in `ctld-tools` — lands on two empty lists with nothing to say so. The mission still
works for FOBs spawned in flight, which go through `registerFOBAsLogistic`, so the symptom is the
confusing half-failure: *"the FOBs I create work, the FARPs I placed do not."*

## Decision

A new `manage_logistics` flag under `modules.CTLD`, defaulting to **true**, and — when it is on —
the build **merges** the VEAF types into whatever the mission declares, at injection time.

```yaml
modules:
  CTLD:
    enabled: true
    manage_logistics: true    # default
```

**Union, not overwrite.** Overwriting was the explicit temptation and it is rejected: it rebuilds
the exact defect [ADR 0016](../../docs/adr/0016-ctld2-sidecar-configuration.md) removed. In v1 the
VEAF wrapper wrote over the mission maker's own values — `slingLoad`, `unitLoadLimits`, `hoverTime`
— so what they wrote was silently discarded. Overwriting the type lists would do the same to anyone
who adds a modded carrier in `ctld-tools`: gone at build time, while the tool keeps showing their
value, since their file is never touched. "What I see in the editor is not what runs" is the worst
failure mode a configuration file can have.

| Case | Overwrite | Union *(chosen)* |
|---|---|---|
| Empty list (the reported mission) | 5 VEAF types | 5 VEAF types — **identical** |
| Maker added `CVN_73` | **loses `CVN_73`** | keeps it, plus the 5 |
| Maker removed `Stennis` on purpose | comes back | comes back → they set the flag to `false` |

`manage_logistics: false` therefore keeps a precise meaning: *the mission owns these lists entirely*.

## Two messages, not one

- **`false` **and** both lists empty** → a prominent warning, in `validate` **and** in the build,
  not buried in the warning list: the mission will start with no logistic point at all from the
  editor. That is worth being loud about.
- **`true` and the merge actually added something** → one informational build line naming the types
  added. The injected configuration then differs from the file on disk, and the maker has to be able
  to see that without diffing the `.miz`.

## Consequences to accept

- **ADR 0016 must be amended in this lot**, on two counts: `mission.yaml` no longer carries "only an
  on/off flag" for CTLD, and the sidecar is no longer injected strictly "verbatim" when the flag is
  on. Leaving the ADR contradicting the code is how the `[Unreleased]` drift happened.
- The scaffold keeps pre-filling the lists even though the build would now cover it: the maker
  should see the types in `ctld-tools`, not just in a generated artifact. In the normal case the
  merge then adds nothing and stays silent.

## Definition of done

- The three rows of the table above are each covered by a test, on the real injection path.
- A mission with `logisticUnitTypes: []` and the flag left at its default builds a
  `CTLD_userConfig.lua` carrying the five VEAF types, and the generated file says which ones VEAF
  added.
- `validate` fails loudly on `false` + empty, and says nothing when the maker owns a non-empty list.
- Documentation updated in both languages, ADR 0016 amended, `CHANGELOG.md` entry.
- Coverage gate raised if measured coverage moves more than ~2 points above it.

---

## Tickets, in full

---
Status: ✅ done
---

## 01 — The `manage_logistics` flag, written into every scaffolded mission

The flag must be **visible in the file**, not merely defaulted in code: a maker who never sees the
key cannot know the behaviour exists, and that invisibility is the whole defect this lot fixes.

### Do

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

### Watch out

The defaults file is a **lockstep** obligation (CLAUDE.md §9.7): the shipped default must match what
the generator produces, in the same lot. A test already compares the two — keep it green.

### Done when

A mission scaffolded with CTLD enabled contains `manage_logistics: true` in plain sight;
`CTLD: true`, `CTLD: {enabled: true}` and `{enabled: true, manage_logistics: false}` all validate;
`manage_logistics: "yes"` fails with a readable message.

---

---
Status: ✅ done
---

## 02 — Merge the VEAF types when injecting, without touching the maker's file

### Where

`MissionBuilderWorker._build_ctld_user_config` (`mission_builder/mission_builder_worker.py`) reads
`ctld-config.yaml` and injects it as a Lua long-bracket string. Today it is passed through
verbatim; with the flag on, the YAML is parsed, merged and re-serialised **on the way into the
`.miz`**. The file in the mission folder is never rewritten — it stays the maker's.

### Do

- Factor a `merge_veaf_logistics(catalogue) -> str` into `veaf_libs/ctld_config.py`, next to
  `apply_veaf_overrides`, sharing `VEAF_CONFIG_OVERRIDES` as the single source of the type list.
  Round-trip through ruamel exactly as `apply_veaf_overrides` does: comments, key order and
  formatting must survive, since the maker reads this file in `ctld-tools`.
- Union semantics, order-preserving: the mission's own entries first, VEAF's appended if absent.
  No duplicates.
- A key the engine's catalogue does not define is **skipped, not created** — same rule
  `apply_veaf_overrides` already applies, for the same reason (an older vendored engine).
- Header comment in the generated `CTLD_userConfig.lua` naming the types VEAF added, or stating
  that automatic management is off.

### Done when

The three cases of the PRD table are asserted against the produced `CTLD_userConfig.lua`, not
against the helper in isolation — the defect being fixed is precisely that the wiring, not the
helper, was missing. Round-tripping a catalogue with comments leaves them in place.

---

---
Status: ✅ done
---

## 03 — Say it loudly when a mission will have no logistics

Two distinct messages, both i18n (`fr.json` + `en.json`), keyed near `builder.ctld_no_config`.

### Do

- **`manage_logistics: false` and both type lists empty** → warning in `validate` **and** in the
  build. It must stand out rather than sit in the middle of the warning list: this mission starts
  with no logistic point from the editor at all. Name the two settings and say the flag is off.
- **`manage_logistics: true` and the merge added at least one type** → one informational build
  line listing them, so a maker can see the injected configuration differs from their file.

Silent in every other case — in particular when the maker owns a non-empty list, which is a
legitimate choice and must not nag on every build.

### Done when

The warning fires on the reported shape (`logisticUnitTypes: []`) with the flag off, and does not
fire with the flag on, or with a non-empty list.

---

---
Status: ✅ done
---

## 04 — Documentation, and amend ADR 0016

### Do

- `doc/mission-maker/GUIDE.md` + `.en.md`, CTLD section: what automatic logistics management is,
  which types it covers, that it merges rather than replaces, and when to turn it off. It belongs
  next to the existing "the file is a **complete** configuration" note, which is the rule that makes
  an empty list dangerous in the first place.
- `doc/MISSION_YAML_REFERENCE.md` + `.en.md`: the flag, its default, its shape.
- **`docs/adr/0016-ctld2-sidecar-configuration.md`**: amend, do not rewrite history. Two statements
  stop being true — that `mission.yaml` keeps only an on/off flag for CTLD, and that the sidecar is
  injected verbatim. Record why the exception was made and why it is a union: the ADR's own argument
  against a second configuration channel is what rules out overwriting.
- `CHANGELOG.md` entry, under whatever the version convention is at merge time — the
  `CHORE-VERSION-AT-MERGE` lot may have replaced the per-PR version heading with
  `[Unreleased]` by then. Not linked: that lot is not on `develop` yet.

### Done when

`poetry run docs-check` is green and a reader of the guide can tell, without reading any code,
what their mission will do with an empty list.

---
