"""A mission nobody touched must not move because of the sequence normalisation.

`FIX-GROUP-CONTAINER-SHAPE` asks for this in as many words: the warehouses fix before it was safe
*because* it was measured, and normalising the mission's sequence tables would be worthless if it moved
every untouched mission's diff.

**A raw byte round trip through the VEAF writer was never identical, and that is not what this
asserts.** `write_mission_folder` re-serialises through `luadata` with `sort=True`, so it reorders keys
and re-indents whatever it is handed — DCS does the same on every save, which is why a raw diff of an
original against VEAF's output has always been misleading. The property that *is* meaningful, and that
this file pins, is narrower and exactly the one the PRD needs: **serialising a mission with the
normalisation applied produces the same bytes as serialising it without.**

The fixtures are the repository's own mission folders under `test/veaf-tools/`, including the three
verification missions — one of which is the mission whose holed tables opened this lot.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import luadata
import pytest
from mission_tools.miz_tools import read_mission_folder, write_mission_folder
from mission_tools.sequence_normalisation import normalise_mission_sequences

_REPO_ROOT = Path(__file__).resolve().parents[3]
_MISSIONS_ROOT = _REPO_ROOT / "test" / "veaf-tools"

#: The exact call `write_miz` / `write_mission_folder` make.
_SERIALIZE = dict(indent="  ", indent_level=0, always_provide_keyname=True, sort=True)


def _mission_folders() -> list[Path]:
    """Every repository mission folder holding a loose `src/mission/mission`."""
    if not _MISSIONS_ROOT.is_dir():
        return []
    return sorted(p for p in _MISSIONS_ROOT.iterdir() if (p / "src" / "mission" / "mission").is_file())


_FOLDERS = _mission_folders()
_IDS = [folder.name for folder in _FOLDERS]


def _raw_parse(folder: Path) -> Any:
    """Parse the loose mission table without going through the normalising read path."""
    text = (folder / "src" / "mission" / "mission").read_text(encoding="utf-8")
    return luadata.unserialize(text, keep_as_dict=["trig", "trigrules"])


def _copy_mission(source: Path, tmp_path: Path) -> Path:
    """Copy just the loose mission files, so a test writes into its own directory."""
    target = tmp_path / source.name
    exploded = target / "src" / "mission"
    exploded.mkdir(parents=True)
    for name in ("mission", "options", "warehouses", "theatre"):
        origin = source / "src" / "mission" / name
        if origin.is_file():
            (exploded / name).write_bytes(origin.read_bytes())
    l10n = source / "src" / "mission" / "l10n" / "DEFAULT"
    if l10n.is_dir():
        copy_to = exploded / "l10n" / "DEFAULT"
        copy_to.mkdir(parents=True)
        for origin in l10n.iterdir():
            if origin.is_file():
                (copy_to / origin.name).write_bytes(origin.read_bytes())
    return target


@pytest.mark.skipif(not _FOLDERS, reason="no mission folder under test/veaf-tools")
@pytest.mark.parametrize("source", _FOLDERS, ids=_IDS)
class TestTheNormalisationAddsNoChange:
    def test_normalising_does_not_change_the_serialised_bytes(self, source: Path) -> None:
        """The measurement the PRD demanded, run over every mission in the repository."""
        untouched = luadata.serialize(_raw_parse(source), **_SERIALIZE)
        normalised_content = _raw_parse(source)
        normalise_mission_sequences(normalised_content)
        assert luadata.serialize(normalised_content, **_SERIALIZE) == untouched

    def test_no_repository_mission_is_holed(self, source: Path, tmp_path: Path) -> None:
        # Which is *why* the assertion above holds. It also turns a hole committed by accident into a
        # named failure rather than a silent renumbering.
        holes = read_mission_folder(_copy_mission(source, tmp_path)).sequence_holes
        assert holes == [], "\n".join(str(hole) for hole in holes)

    def test_a_second_write_produces_the_same_bytes(self, source: Path, tmp_path: Path) -> None:
        # What a mission maker actually sees: build twice, get the same file. The first write
        # re-indents and reorders (luadata with sort=True, as DCS does on every save); the second must
        # add nothing on top of that.
        folder = _copy_mission(source, tmp_path)
        mission_file = folder / "src" / "mission" / "mission"
        write_mission_folder(read_mission_folder(folder), folder)
        after_first = mission_file.read_bytes()
        write_mission_folder(read_mission_folder(folder), folder)
        assert mission_file.read_bytes() == after_first


@pytest.mark.skipif(not _FOLDERS, reason="no mission folder under test/veaf-tools")
def test_normalising_an_already_normalised_mission_is_a_no_op() -> None:
    # Idempotence: a mission that has been through the pipeline once is not renumbered again.
    content = read_mission_folder(_FOLDERS[0]).mission_content
    assert normalise_mission_sequences(content) == []
