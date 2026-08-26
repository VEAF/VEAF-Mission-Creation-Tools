---
Status: ✅ done
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
