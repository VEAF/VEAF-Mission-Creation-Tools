"""Tests for the guided airfield-frequency capture, against a fake DCS."""

from __future__ import annotations

import json
import zipfile
from pathlib import Path
from typing import Any

import pytest

from veaf_build.dcs_data import airfield_freqs as A
from veaf_build.dcs_data import airfield_freqs_session as S


def _install(tmp_path: Path, *folders: str) -> Path:
    for folder in folders:
        (tmp_path / "Mods" / "terrains" / folder).mkdir(parents=True)
        (tmp_path / "Mods" / "terrains" / folder / "Radio.lua").write_text("radio = {}\n", encoding="utf-8")
    (tmp_path / "Mods" / "terrains" / "NoRadio").mkdir(parents=True)
    return tmp_path


def test_installed_theatres_use_the_names_missions_use(tmp_path: Path) -> None:
    install = _install(tmp_path, "Caucasus", "GermanyColdWar", "Sinai", "SomeModMap")
    assert S.installed_theatres(install) == (["Caucasus", "GermanyCW", "SinaiMap"], ["SomeModMap"])


def test_waiting_stops_at_once_on_refused_credentials() -> None:
    from veaf_libs.dcs_fiddle_client import FiddleAuthError

    calls: list[str] = []

    def exec_lua(code: str) -> Any:
        calls.append(code)
        raise FiddleAuthError("the DCS hook rejected the credentials (401)")

    clock = _Clock()
    with pytest.raises(FiddleAuthError):
        S.wait_for_theatre(exec_lua, "Syria", 900, clock=clock, sleep=clock.sleep)
    assert len(calls) == 1 and clock.now == 0.0


def test_by_default_only_theatres_without_a_capture_are_captured(tmp_path: Path) -> None:
    dumps = tmp_path / "dumps"
    dumps.mkdir()
    (dumps / "Caucasus.json").write_text("{}", encoding="utf-8")
    assert S.theatres_to_capture(["Caucasus", "Syria"], [], dumps) == ["Syria"]
    assert S.theatres_to_capture(["Caucasus", "Syria"], ["caucasus"], dumps) == ["Caucasus"]


def test_a_requested_theatre_that_is_not_installed_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="Kola"):
        S.theatres_to_capture(["Caucasus"], ["Kola"], tmp_path)


def test_the_capture_mission_is_a_blank_on_the_theatre(tmp_path: Path) -> None:
    path = S.write_capture_mission("PersianGulf", tmp_path / "Missions")
    assert path.name == "veaf-capture-frequencies-PersianGulf.miz"
    with zipfile.ZipFile(path) as archive:
        assert archive.read("theatre").decode() == "PersianGulf"


class _Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds


def test_waiting_goes_through_a_dead_hook_and_another_map(tmp_path: Path) -> None:
    answers: list[Any] = [RuntimeError("cannot reach the DCS hook"), "none", "Caucasus", "Caucasus", "PersianGulf"]

    def exec_lua(_code: str) -> Any:
        answer = answers.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return answer

    others: list[str] = []
    clock = _Clock()
    S.wait_for_theatre(exec_lua, "PersianGulf", 60, on_other=others.append, clock=clock, sleep=clock.sleep)
    assert others == ["Caucasus"]  # said once, not at every poll
    assert answers == []


def test_waiting_gives_up_saying_what_it_saw() -> None:
    clock = _Clock()
    with pytest.raises(TimeoutError, match="a mission on Syria"):
        S.wait_for_theatre(lambda _c: "Syria", "PersianGulf", 10, clock=clock, sleep=clock.sleep)


def test_capture_writes_the_dump_with_tacan(tmp_path: Path) -> None:
    install = _install(tmp_path, "PersianGulf")
    (install / "Mods" / "terrains" / "PersianGulf" / "Beacons.lua").write_text(
        "{ beaconId = 'airfield4_8'; type = BEACON_TYPE_VORTAC; channel = 96; position = { 1, 2, 3 }; };\n",
        encoding="utf-8",
    )
    payload = {
        "theatre": "PersianGulf",
        "airdromes": [{"id": 4, "name": "Al Dhafra AFB", "source": "terrain", "freqs": [[251100000, 0]]}],
    }
    path, records, tacans = S.capture_theatre(lambda _c: payload, "PersianGulf", install, tmp_path / "dumps")
    assert tacans == {4: "96X"} and records[0]["freqs"] == [251.1]
    assert json.loads(path.read_text(encoding="utf-8"))["airdromes"][0]["tacan"] == "96X"


def test_capture_refuses_a_map_switched_under_it(tmp_path: Path) -> None:
    payload = {"theatre": "Syria", "airdromes": [{"id": 1, "name": "x", "freqs": [[251e6, 0]]}]}
    with pytest.raises(ValueError, match="Syria"):
        S.capture_theatre(lambda _c: payload, "PersianGulf", tmp_path, tmp_path / "dumps")
    assert not (tmp_path / "dumps").exists()


def test_capture_sends_the_generator_s_lua() -> None:
    seen: list[str] = []

    def exec_lua(code: str) -> Any:
        seen.append(code)
        return {"theatre": "Caucasus", "airdromes": [{"id": 22, "name": "Batumi", "freqs": [[260e6, 0]]}]}

    with pytest.raises(ValueError):  # caught before any write: the expected map is another one
        S.capture_theatre(exec_lua, "Syria", Path("nowhere"), Path("nowhere"))
    assert seen == [A.CAPTURE_LUA]
