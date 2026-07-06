"""QRA `start: false` must stay inside its list item (FIX-CONVERT-V5-INVALID-YAML).

Regression: the `converter.yaml.qra.start_comment` translation hard-coded 6-space
indentation (`      start: false  # …`), so when QRA was disabled in v5 the line
landed at the `definitions:` sequence level (indent 6) instead of inside the
`- name:` item (indent 8). DCS-side that produced an unparseable mission.yaml
(`expected <block end>, but found '?'`). The field is now emitted with the same
`field` prefix as every other QRA field, and the translation holds only the comment.
"""

from __future__ import annotations

import yaml
from mission_builder.v5_converter import _emit_qra_definitions


def _doc(lines: list[str]) -> str:
    """Nest the emitted lines under modules.QRA, as _build_mission_yaml does."""
    return "\n".join(["modules:", "  QRA:", "    enabled: true"] + lines)


def test_qra_start_false_yaml_parses() -> None:
    lines = _emit_qra_definitions(
        False,
        [{"name": "QRA_X", "coalition": "RED", "airport_link": "Marj Ruhayyil", "start": False}],
        indent=4,
    )
    data = yaml.safe_load(_doc(lines))  # must not raise
    defs = data["modules"]["QRA"]["definitions"]
    assert len(defs) == 1
    assert defs[0]["name"] == "QRA_X"
    # the disabled flag belongs to the item, not to the sequence
    assert defs[0]["start"] is False


def test_qra_start_false_indented_under_item() -> None:
    lines = _emit_qra_definitions(False, [{"name": "Q", "start": False}], indent=4)
    start_line = next(line for line in lines if "start:" in line)
    # field indent = base(4) + 4 = 8 spaces, aligned with the other QRA fields
    assert start_line.startswith("        start: false  #"), start_line


def test_multiple_qra_with_start_false_parse() -> None:
    # two disabled definitions — the bug also broke the boundary before the 2nd item
    lines = _emit_qra_definitions(
        False,
        [{"name": "A", "start": False}, {"name": "B", "coalition": "RED", "start": False}],
        indent=4,
    )
    defs = yaml.safe_load(_doc(lines))["modules"]["QRA"]["definitions"]
    assert [d["name"] for d in defs] == ["A", "B"]
    assert all(d["start"] is False for d in defs)


def test_qra_start_true_emits_no_start_line() -> None:
    # default start (True) must not emit a start: line at all
    lines = _emit_qra_definitions(False, [{"name": "Q", "start": True}], indent=4)
    assert not any("start:" in line for line in lines)
