"""Tests for veaf_libs.known_limitations (FIX-SCRATCH-MISSION-FINDINGS ticket 13)."""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs.known_limitations import (
    GENERATED_BEGIN,
    GENERATED_END,
    active_limitations,
    load_known_limitations,
    render_markdown,
    validate_limitations,
)

_PAGE = Path(__file__).parents[3] / "docs" / "agents" / "dcs-runtime-traps.md"

_DCS = {
    "id": "a-dcs-trap",
    "kind": "dcs",
    "area": "spawning",
    "title": "t",
    "symptom": "s",
    "workaround": "w",
    "measured": "2026-09-21",
}
_TOOL = {"id": "a-tool-gap", "kind": "tool", "area": "mcp", "title": "t", "symptom": "s", "workaround": "w"}


def test_every_shipped_entry_has_its_fields() -> None:
    entries = load_known_limitations()
    assert entries
    validate_limitations(entries)  # raises on the first defect
    assert {e["kind"] for e in entries} == {"dcs", "tool"}


@pytest.mark.parametrize("field", ["id", "kind", "area", "title", "symptom", "workaround"])
def test_a_missing_field_is_refused(field: str) -> None:
    entry = {k: v for k, v in _DCS.items() if k != field}
    with pytest.raises(ValueError, match=field):
        validate_limitations([entry])


def test_a_dcs_entry_needs_its_measurement_date() -> None:
    with pytest.raises(ValueError, match="measured"):
        validate_limitations([{k: v for k, v in _DCS.items() if k != "measured"}])


def test_a_dcs_entry_cannot_be_fixed() -> None:
    """DCS is not ours to fix: a `fixed_in` there would silently hide a behaviour that is still true."""
    with pytest.raises(ValueError, match="fixed_in"):
        validate_limitations([{**_DCS, "fixed_in": "6.25.0"}])


def test_ids_are_unique() -> None:
    with pytest.raises(ValueError, match="duplicate"):
        validate_limitations([_TOOL, dict(_TOOL)])


def test_an_unknown_kind_is_refused() -> None:
    with pytest.raises(ValueError, match="kind"):
        validate_limitations([{**_TOOL, "kind": "other"}])


def test_a_fixed_tool_limitation_is_not_returned_from_its_release_on() -> None:
    entries = [{**_TOOL, "fixed_in": "6.25.0"}]
    assert active_limitations(entries, "6.24.3") == entries
    assert active_limitations(entries, "6.25.0") == []
    assert active_limitations(entries, "6.26.1") == []


def test_a_dcs_entry_is_returned_whatever_the_version() -> None:
    for version in ("0.0.1", "6.25.0", "99.0.0", "unknown"):
        assert active_limitations([_DCS], version) == [_DCS]


def test_an_unreadable_version_returns_everything() -> None:
    """A dev install may report no version; hiding a limitation there is the wrong way to be wrong."""
    entries = [{**_TOOL, "fixed_in": "6.25.0"}]
    assert active_limitations(entries, "unknown") == entries


def test_the_kind_filter() -> None:
    assert active_limitations([_DCS, _TOOL], "6.24.0", kind="dcs") == [_DCS]
    assert active_limitations([_DCS, _TOOL], "6.24.0", kind="tool") == [_TOOL]


def test_the_page_carries_the_rendering_of_the_file_and_no_copy_of_its_own() -> None:
    page = _PAGE.read_text(encoding="utf-8")
    start = page.index(GENERATED_BEGIN) + len(GENERATED_BEGIN)
    end = page.index(GENERATED_END)
    assert page[start:end].strip() == render_markdown(load_known_limitations()).strip(), (
        "docs/agents/dcs-runtime-traps.md is stale: run `poetry run python -m veaf_libs.known_limitations`"
    )
    # outside the generated block, no entry of the file is written a second time
    outside = page[: page.index(GENERATED_BEGIN)] + page[end:]
    for entry in load_known_limitations():
        if entry["kind"] == "dcs":
            assert entry["title"] not in outside, entry["id"]


def test_the_page_renders_only_the_dcs_entries() -> None:
    rendered = render_markdown([_DCS, _TOOL])
    assert "a-dcs-trap" in rendered
    assert "a-tool-gap" not in rendered
