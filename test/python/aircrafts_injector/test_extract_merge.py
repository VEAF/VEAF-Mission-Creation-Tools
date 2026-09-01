"""FEAT-EXTRACT-MERGE — ``extract-aircraft-groups`` can merge into the YAML it finds.

Background
----------
``_write_structure`` opened its target with ``open(path, "w")``: whatever the catalogue had
gathered was gone. That made the command one-shot — no second mission could contribute its
dynamic-slot templates, and no re-extraction could follow a Mission Editor change without
throwing away every hand edit and every group the new mission happens not to carry.

``--merge`` turns the write into a merge, with the rule the 2026-08-30 meeting settled on:
**the mission wins, and the report says so.** A group of the same name, in the same
category / coalition / country, is replaced by the mission's version and **named** in the
output; anything the file holds that the mission does not is kept.

Merging is opt-in, so a script that has always received a freshly rebuilt file still does.

Every assertion below reads the **file on disk after two successive extractions** — the
in-memory structure was never the thing that got clobbered.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml
from aircrafts_injector import AircraftGroupsExtractorWorker
from upstream_miz import make_upstream_miz

# ---------------------------------------------------------------------------
# Fixtures: two missions that overlap on exactly one dynamic-slot template
# ---------------------------------------------------------------------------


def _template(name: str, unit_type: str, livery: str) -> dict[str, Any]:
    """A dynamic-slot template group (``dynSpawnTemplate``), ADR 0002 family C."""
    return {
        "name": name,
        "dynSpawnTemplate": True,
        "units": [{"name": f"{name}-1", "type": unit_type, "livery_id": livery}],
    }


def _spawnable(name: str, unit_type: str) -> dict[str, Any]:
    """A spawnable aircraft group (``veafSpawn-`` prefix), ADR 0002 family B."""
    return {"name": name, "units": [{"name": f"{name}-1", "type": unit_type}]}


def _first_mission(folder: Path) -> Path:
    """The catalogue's first contributor: an F-15 template, a Huey template, one blue spawnable."""
    return make_upstream_miz(
        folder=folder,
        name="first.miz",
        aircraft={
            "blue": {
                "USA": {
                    "plane": [
                        _template("Template-F15", "F-15ESE", "usaf standard"),
                        _spawnable("veafSpawn-CAP-Eagle", "F-15ESE"),
                    ],
                    "helicopter": [_template("Template-Huey", "UH-1H", "us army")],
                }
            }
        },
    )


def _second_mission(folder: Path) -> Path:
    """The second contributor: the same F-15 template restyled, plus two newcomers."""
    return make_upstream_miz(
        folder=folder,
        name="second.miz",
        aircraft={
            "blue": {
                "USA": {
                    "plane": [
                        _template("Template-F15", "F-15ESE", "aggressors"),
                        _template("Template-Viper", "F-16C_50", "usaf standard"),
                    ],
                    "helicopter": [],
                }
            },
            "red": {"Russia": {"plane": [_spawnable("veafSpawn-CAP-Flanker", "Su-27")]}},
        },
    )


def _extract(miz: Path, spawnables: Path, dynamic: Path, *, merge: bool = False, silent: bool = True) -> Any:
    """Run one full extraction of *miz* into the two family files."""
    worker = AircraftGroupsExtractorWorker(
        input_mission=miz,
        output_spawnables=spawnables,
        output_dynamic_templates=dynamic,
        merge=merge,
    )
    worker.extract(silent=silent)
    return worker


def _planes(path: Path, coalition: str = "blue", country: str = "USA") -> dict[str, Any]:
    """Read the airplane groups of one coalition/country **from the file on disk**."""
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return ((data.get("airplanes") or {}).get("coalitions") or {}).get(coalition, {}).get(country, {})


def _helicopters(path: Path, coalition: str = "blue", country: str = "USA") -> dict[str, Any]:
    """Read the helicopter groups of one coalition/country **from the file on disk**."""
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return ((data.get("helicopters") or {}).get("coalitions") or {}).get(coalition, {}).get(country, {})


# ---------------------------------------------------------------------------
# Merging is opt-in: today's callers keep getting a rebuilt file
# ---------------------------------------------------------------------------


class TestWithoutMergeTheFileIsStillReplaced:
    """The default is unchanged — this is the behaviour existing scripts depend on."""

    def test_second_extraction_drops_what_the_first_wrote(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        assert "Template-F15" in _planes(dynamic)

        _extract(_second_mission(tmp_path / "b"), spawnables, dynamic)

        # Nothing of the first mission survives: that is the defect, kept as the default.
        assert "Template-Viper" in _planes(dynamic)
        assert _helicopters(dynamic) == {}


# ---------------------------------------------------------------------------
# --merge: the mission wins, the rest is kept
# ---------------------------------------------------------------------------


class TestMergeKeepsWhatTheMissionDoesNotHave:
    def test_groups_absent_from_the_second_mission_survive(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        _extract(_second_mission(tmp_path / "b"), spawnables, dynamic, merge=True)

        # The Huey the second mission never had is still in the catalogue…
        assert "Template-Huey" in _helicopters(dynamic)
        # …alongside both airplane templates, the old one and the newcomer.
        assert sorted(_planes(dynamic)) == ["Template-F15", "Template-Viper"]

    def test_a_hand_edit_the_mission_does_not_touch_is_preserved(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        # A mission maker adds a template by hand, for an aircraft no mission carries.
        data = yaml.safe_load(dynamic.read_text(encoding="utf-8"))
        data["airplanes"]["coalitions"]["blue"]["USA"]["Template-HandMade"] = _template(
            "Template-HandMade", "AV8BNA", "custom"
        )
        dynamic.write_text(yaml.dump(data, sort_keys=True, allow_unicode=True), encoding="utf-8")

        _extract(_second_mission(tmp_path / "b"), spawnables, dynamic, merge=True)

        groups = _planes(dynamic)
        assert "Template-HandMade" in groups
        assert groups["Template-HandMade"]["units"][0]["livery_id"] == "custom"

    def test_a_new_coalition_is_added_next_to_the_existing_one(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        _extract(_second_mission(tmp_path / "b"), spawnables, dynamic, merge=True)

        # The second mission only has a red spawnable; the first mission's blue one is untouched.
        assert "veafSpawn-CAP-Flanker" in _planes(spawnables, coalition="red", country="Russia")
        assert "veafSpawn-CAP-Eagle" in _planes(spawnables)


class TestTheMissionWins:
    def test_a_group_present_in_both_takes_the_missions_version(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        assert _planes(dynamic)["Template-F15"]["units"][0]["livery_id"] == "usaf standard"

        _extract(_second_mission(tmp_path / "b"), spawnables, dynamic, merge=True)

        assert _planes(dynamic)["Template-F15"]["units"][0]["livery_id"] == "aggressors"

    def test_every_replacement_is_named_in_the_output(self, tmp_path: Path, capsys: Any) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)
        capsys.readouterr()  # drop the first run's output

        worker = _extract(_second_mission(tmp_path / "b"), spawnables, dynamic, merge=True, silent=False)

        output = capsys.readouterr().out
        # The replaced group is named; the ones merely added are not reported as replacements.
        assert "Template-F15" in output
        assert worker.replaced_groups == ["airplanes / blue / USA / Template-F15"]

    def test_nothing_is_reported_when_nothing_was_replaced(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        worker = _extract(_first_mission(tmp_path / "a"), spawnables, dynamic, merge=True)

        assert worker.replaced_groups == []


class TestBothFamiliesMerge:
    """The meeting named the dynamic templates, but both families go through the same write."""

    def test_spawnables_merge_too(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"
        first = make_upstream_miz(
            folder=tmp_path / "a",
            name="first.miz",
            aircraft={"blue": {"USA": {"plane": [_spawnable("veafSpawn-CAP-Alpha", "F-15ESE")]}}},
        )
        second = make_upstream_miz(
            folder=tmp_path / "b",
            name="second.miz",
            aircraft={"blue": {"USA": {"plane": [_spawnable("veafSpawn-CAP-Bravo", "F-16C_50")]}}},
        )

        _extract(first, spawnables, dynamic)
        worker = _extract(second, spawnables, dynamic, merge=True)

        assert sorted(_planes(spawnables)) == ["veafSpawn-CAP-Alpha", "veafSpawn-CAP-Bravo"]
        assert worker.replaced_groups == []


# ---------------------------------------------------------------------------
# Edge cases: nothing there, and something unusable there
# ---------------------------------------------------------------------------


class TestMergeWithNothingToMergeInto:
    def test_a_missing_target_behaves_as_a_plain_extraction(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic, merge=True)

        assert sorted(_planes(dynamic)) == ["Template-F15"]
        assert sorted(_helicopters(dynamic)) == ["Template-Huey"]

    def test_an_empty_target_behaves_as_a_plain_extraction(self, tmp_path: Path) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"
        dynamic.write_text("", encoding="utf-8")
        spawnables.write_text("", encoding="utf-8")

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic, merge=True)

        assert sorted(_planes(dynamic)) == ["Template-F15"]


class TestAnUnusableTargetFailsLoudly:
    """A target we cannot read must abort the run — never be overwritten in silence."""

    BAD_CONTENT = {
        "not-yaml-at-all": "airplanes: [oops\n  - : :\n",
        "top-level-is-a-list": "- airplanes\n- helicopters\n",
        "coalitions-is-a-list": "airplanes:\n  coalitions:\n    - blue\n",
        "country-holds-a-list": "airplanes:\n  coalitions:\n    blue:\n      USA:\n        - Template-F15\n",
    }

    @pytest.mark.parametrize("case", sorted(BAD_CONTENT))
    def test_the_run_fails_and_the_file_is_untouched(self, tmp_path: Path, case: str) -> None:
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"
        dynamic.write_text(self.BAD_CONTENT[case], encoding="utf-8")
        before = dynamic.read_bytes()

        with pytest.raises(ValueError):
            _extract(_first_mission(tmp_path / "a"), spawnables, dynamic, merge=True)

        assert dynamic.read_bytes() == before

    def test_without_merge_an_unusable_target_is_simply_rebuilt(self, tmp_path: Path) -> None:
        """The target is never read when merging is off, so nothing can fail on its content."""
        spawnables, dynamic = tmp_path / "spawnables.yaml", tmp_path / "dynamic.yaml"
        dynamic.write_text(self.BAD_CONTENT["not-yaml-at-all"], encoding="utf-8")

        _extract(_first_mission(tmp_path / "a"), spawnables, dynamic)

        assert sorted(_planes(dynamic)) == ["Template-F15"]
