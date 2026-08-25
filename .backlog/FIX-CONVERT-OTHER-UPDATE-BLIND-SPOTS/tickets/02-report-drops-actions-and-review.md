# 02 — The conversion report renders neither `actions` nor `manual_review`

Status: ⬜ ready

Type: fix · Files: `src/python/veaf-tools/mission_builder/v5_converter.py`,
`src/python/veaf-tools/mission_builder/other_converter.py`

## The defect

`ConversionReport` carries two summary lists, documented as what the run has to say:

```python
actions: list[str]        # "High-level descriptions of actions taken (shown in the summary)"
manual_review: list[str]  # actionable items
```

Neither reaches the markdown. `self.actions` occurs **zero** times in the report builder;
`self.manual_review` occurs once, at `v5_converter.py:310`, only to count items for the
`⚠️ N éléments nécessitent une action manuelle` line. The `## Actions effectuées` section is built
from hard-coded steps, and `### ⚠️ Avertissements de conversion` renders `warnings`, a third list.

So everything `convert-other --update` is written to report goes into the void:

| Collected at | Content | Rendered |
|---|---|---|
| `other_converter.py:609` | scripts added upstream | no |
| `other_converter.py:611` | scripts updated upstream | no |
| `other_converter.py:613` | scripts removed upstream | no |
| `other_converter.py:620` | a load delay that no longer matches `mission.yaml` | no |

## Measured on the 2026-08-25 Foothold refresh

Five missions refreshed, one of them (Syria) with a renamed setup script and all five with six
mismatched delays each. Every report printed the same two lines:

```
- ⚠️ 10 éléments nécessitent une action manuelle
### ⚠️ Avertissements de conversion
*Aucun — la migration s'est terminée sans avertissement.*
```

The counter did not even move for Syria, which had one extra `removed` item — worth checking while
fixing this, since it suggests the counter is computed before the update section appends to the
lists.

## Why this is the first ticket of the lot

Both other defects of this lot were **detected by the code** and lost at the rendering step. The
delay mismatch in particular: `_delay_changes` produced its six lines per mission and appended them
to `manual_review`. The tool knew. It just had no way to say so.

## Definition of done

- [ ] `actions` and `manual_review` are rendered as their own sections in the markdown report
- [ ] `convert-other --update` on a release with an added, an updated and a removed script names all
      three in the written report
- [ ] The summary counter includes the update items (check the ordering between appending and
      counting)
- [ ] `doc/mission-maker/FOOTHOLD.md` and the mission-repository README stop promising a report the
      tool does not produce — or keep the promise because it now holds
- [ ] Test asserting the rendered text, not the list contents: a report whose `manual_review` is
      populated must print those lines
