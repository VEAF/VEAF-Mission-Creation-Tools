"""The sweep's wait names a dead `dcs-serve` instead of waiting for it (FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 09).

On 2026-10-13 a `dcs-serve` started by another session exited a few minutes after `terrain-sweep` had found it
running. The sweep stayed alive and silent for about twenty minutes, DCS's bridge logging « no connection for 30s ».
"""

import pytest
from veaf_libs.clear_ground_survey import SurveyError
from veaf_libs.dcs_bridge_capture import BridgeHttpError
from veaf_tools.commands import clear_ground

_URL = "http://127.0.0.1:8080"


@pytest.fixture(autouse=True)
def _no_real_sleep(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(clear_ground.time, "sleep", lambda _seconds: None)


def _refuse(_code: str) -> str:
    raise RuntimeError("connection refused")


def test_a_server_that_no_longer_answers_stops_the_wait_at_once(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(clear_ground, "is_serving", lambda url: False)
    with pytest.raises(RuntimeError, match="dcs-serve") as raised:
        clear_ground._wait_for_survey_mission(_refuse, "Normandy", 900, _URL)
    assert _URL in str(raised.value)


def test_a_server_still_there_is_waited_for_until_the_deadline(monkeypatch: pytest.MonkeyPatch) -> None:
    """A connection error with the server up is DCS's bridge not connected yet: that is worth waiting for."""
    monkeypatch.setattr(clear_ground, "is_serving", lambda url: True)
    with pytest.raises(RuntimeError, match="connection refused"):
        clear_ground._wait_for_survey_mission(_refuse, "Normandy", 0, _URL)


def test_no_mission_yet_is_still_retried_while_the_server_answers(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(clear_ground, "is_serving", lambda url: True)
    answers = iter([BridgeHttpError(503, "no mission"), "Normandy 0"])

    def exec_lua(_code: str) -> str:
        answer = next(answers)
        if isinstance(answer, Exception):
            raise answer
        return answer

    clear_ground._wait_for_survey_mission(exec_lua, "Normandy", 900, _URL)


def test_a_mission_that_is_not_the_survey_mission_is_still_refused_at_once(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(clear_ground, "is_serving", lambda url: True)
    with pytest.raises(SurveyError):
        clear_ground._wait_for_survey_mission(lambda _code: "Caucasus 0", "Normandy", 900, _URL)


def test_the_wait_says_so_once_at_half_time(monkeypatch: pytest.MonkeyPatch) -> None:
    printed: list[str] = []
    monkeypatch.setattr(clear_ground, "is_serving", lambda url: True)
    monkeypatch.setattr(clear_ground.console, "print", lambda message, *a, **k: printed.append(str(message)))
    clock = iter([0.0, 0.0, 1.0, 6.0, 7.0, 11.0, 12.0])  # start, half-time, three checks, deadline
    monkeypatch.setattr(clear_ground.time, "monotonic", lambda: next(clock, 99.0))
    with pytest.raises(RuntimeError):
        clear_ground._wait_for_survey_mission(_refuse, "Normandy", 10, _URL)
    assert len([m for m in printed if "5" in m and ("après" in m or "after" in m)]) == 1
