"""FEAT-DYNSLOT-CATALOGUE-REFRESH ticket 01 — the extraction must write UTF-8.

``_write_structure`` opened its target with ``open(path, "w")`` — no ``encoding``, so the
process locale's codepage, which is ``cp1252`` on a French Windows. ``yaml.dump`` is called
with ``allow_unicode=True``, so any accent in a livery, a callsign or a group name was written
as a cp1252 byte, while **every reader** of the catalogue passes ``encoding="utf-8"``:
``AircraftGroupsYAMLValidator.load``, ``AircraftGroupsInjectorWorker.load_yaml_data`` and the
``--merge`` path's ``_read_target_structure``.

So the command produced a file the tool could not consume, and said nothing about it. Measured
on the extract VEAF received on 2026-09-21, whose AH-64D and Mi-8MTV2 templates carry the
callsigns ``Armée de l'air11`` and ``Déchet11``::

    utf-8 read FAILS -> 'utf-8' codec can't decode byte 0xe9 in position 195704

The mission maker's only clue came one command later, as a ``UnicodeDecodeError`` naming a byte
offset — and on the ``--merge`` path as a plain refusal to do anything, since the handler there
routes through ``logger.error``, which aborts.

These tests read the **bytes on disk**, not the in-memory structure: the encoding is only ever
decided at the write.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml
from aircrafts_injector import AircraftGroupsExtractorWorker
from aircrafts_injector.aircrafts_injector_worker import (
    AircraftGroupsInjectorWorker,
    AircraftGroupsYAMLValidator,
)
from upstream_miz import make_upstream_miz

#: A livery name with an accent, as DCS ships them. The AH-64D of the 2026-09-21 extract
#: carried the same character in its callsign.
ACCENTED_LIVERY = "Armée de l'air"

#: The same string encoded both ways. UTF-8 spells ``é`` on two bytes, cp1252 on one.
UTF8_E_ACUTE = b"\xc3\xa9"
CP1252_E_ACUTE = b"\xe9"


def _mission_with_an_accented_livery(folder: Path) -> Path:
    """A mission holding one dynamic-slot template whose livery carries an accent."""
    return make_upstream_miz(
        folder=folder,
        name="accented.miz",
        aircraft={
            "blue": {
                "France": {
                    "plane": [
                        {
                            "name": "Template-Mirage",
                            "dynSpawnTemplate": True,
                            "units": [
                                {
                                    "name": "Template-Mirage-1",
                                    "type": "M-2000C",
                                    "livery_id": ACCENTED_LIVERY,
                                }
                            ],
                        }
                    ]
                }
            }
        },
    )


def _extract(miz: Path, spawnables: Path, dynamic: Path, *, merge: bool = False) -> None:
    """Run one full extraction of *miz* into the two family files."""
    AircraftGroupsExtractorWorker(
        input_mission=miz,
        output_spawnables=spawnables,
        output_dynamic_templates=dynamic,
        merge=merge,
    ).extract(silent=True)


def _livery_on_disk(path: Path) -> str:
    """Read the template's livery back the way every consumer does: as UTF-8."""
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    groups = ((data.get("airplanes") or {}).get("coalitions") or {}).get("blue", {}).get("France", {})
    units: Any = groups["Template-Mirage"]["units"]
    if isinstance(units, dict):
        units = list(units.values())
    return str(units[0]["livery_id"])


@pytest.fixture
def catalogue(tmp_path: Path) -> Path:
    """The dynamic-slot catalogue of a single extraction, holding the accented livery."""
    dynamic = tmp_path / "dynamic-slot-templates.yaml"
    _extract(_mission_with_an_accented_livery(tmp_path / "src"), tmp_path / "spawnables.yaml", dynamic)
    return dynamic


class TestTheCatalogueIsUtf8OnDisk:
    """The bytes, not the string: this is the assertion the missing argument broke."""

    def test_the_accent_is_written_as_utf8(self, catalogue: Path) -> None:
        raw = catalogue.read_bytes()
        assert UTF8_E_ACUTE in raw, "the accent was not written as UTF-8"
        assert CP1252_E_ACUTE not in raw, "the accent was written in the locale codepage"

    def test_the_whole_file_decodes_as_utf8(self, catalogue: Path) -> None:
        # No assertion needed beyond not raising: a UnicodeDecodeError here is the defect.
        catalogue.read_bytes().decode("utf-8")


class TestTheToolCanReadBackWhatItWrote:
    """Each reader in the worker, against the file the worker just produced."""

    def test_the_livery_round_trips(self, catalogue: Path) -> None:
        assert _livery_on_disk(catalogue) == ACCENTED_LIVERY

    def test_the_validator_loads_it(self, catalogue: Path) -> None:
        validator = AircraftGroupsYAMLValidator(catalogue)
        assert validator.load_yaml() is True, [str(e) for e in validator.errors]

    def test_the_injector_loads_it(self, catalogue: Path, tmp_path: Path) -> None:
        injector = AircraftGroupsInjectorWorker(
            input_yaml=catalogue,
            target_mission=tmp_path / "target.miz",
            output_mission=tmp_path / "out.miz",
        )
        assert injector.load_yaml_data(silent=True) is True

    def test_a_second_extraction_can_merge_over_it(self, catalogue: Path, tmp_path: Path) -> None:
        # --merge reads the target before writing. An unreadable target aborts the run, so
        # before the fix this could not even reach the merge.
        _extract(
            _mission_with_an_accented_livery(tmp_path / "src2"),
            tmp_path / "spawnables.yaml",
            catalogue,
            merge=True,
        )
        assert _livery_on_disk(catalogue) == ACCENTED_LIVERY
