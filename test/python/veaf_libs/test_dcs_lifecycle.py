"""The unattended DCS lifecycle orchestration — launch → load → assert → quit.

The simulator-touching calls (launching DCS, ``net.load_mission``, ``exitProcess``) are validated by a
live run and cannot be unit-tested; what *is* tested here is the orchestration around them: the state
machine, the bounded waits, and the guarantee that a DCS this harness launched is always terminated.
Every seam is faked so no real DCS, process or clock is involved.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from veaf_libs.dcs_fiddle_client import Capabilities, FiddleError
from veaf_libs.dcs_lifecycle import (
    LifecycleConfig,
    find_dcs_executable,
    run_unattended,
)
from veaf_libs.dcs_smoke import Outcome, Result


class FakeProcess:
    """A stand-in for :class:`subprocess.Popen` that reports alive for a fixed number of polls."""

    def __init__(self, alive_polls: int = 0) -> None:
        self._alive_polls = alive_polls
        self.terminated = False
        self.killed = False

    def poll(self) -> int | None:
        if self._alive_polls > 0:
            self._alive_polls -= 1
            return None
        return 0

    def terminate(self) -> None:
        self.terminated = True

    def kill(self) -> None:
        self.killed = True


class FakeClock:
    """A deterministic monotonic clock: ``sleep`` is the only thing that advances it."""

    def __init__(self) -> None:
        self.t = 0.0

    def now(self) -> float:
        return self.t

    def sleep(self, dt: float) -> None:
        self.t += dt


class FakeProber:
    """Returns a queued sequence of :class:`Capabilities`, repeating the last once exhausted."""

    def __init__(self, sequence: list[Capabilities]) -> None:
        self._seq = sequence
        self.calls = 0

    def __call__(self, **_kwargs: object) -> Capabilities:
        caps = self._seq[min(self.calls, len(self._seq) - 1)]
        self.calls += 1
        return caps


def _passing_result() -> Result:
    return Result(outcomes=[Outcome("a-check", True, "returned 'ok'")])


def _cfg(**over: object) -> LifecycleConfig:
    base: dict[str, object] = {"dcs_exe": Path("DCS.exe"), "mission": Path("test.miz")}
    base.update(over)
    return LifecycleConfig(**base)  # type: ignore[arg-type]


class TestHappyPath(unittest.TestCase):
    def setUp(self) -> None:
        self.clock = FakeClock()
        self.process = FakeProcess(alive_polls=1)  # exits on the second quit poll
        self.launched_with: list[Path] = []

    def _run(self) -> object:
        prober = FakeProber(
            [
                Capabilities(hook_alive=False),  # pre-check: nothing running → launch
                Capabilities(hook_alive=True, mission_name=None),  # main menu
                Capabilities(hook_alive=True, mission_name="TestMission"),  # loaded
            ]
        )
        return run_unattended(
            _cfg(),
            launcher=lambda exe: (self.launched_with.append(exe), self.process)[1],
            prober=prober,
            hook_exec=lambda *a, **k: "quitting",
            runner=lambda **_k: _passing_result(),
            sleeper=self.clock.sleep,
            clock=self.clock.now,
        )

    def test_it_launches_loads_asserts_and_exits_zero(self) -> None:
        report = self._run()
        self.assertIsNone(report.error, report.steps)
        self.assertTrue(report.launched)
        self.assertEqual(report.exit_code, 0)
        self.assertEqual(self.launched_with, [Path("DCS.exe")])

    def test_it_quits_the_instance_it_launched(self) -> None:
        report = self._run()
        self.assertTrue(report.quit_clean)
        self.assertFalse(self.process.killed)


class TestAlreadyRunning(unittest.TestCase):
    def _run(self, allow_running: bool) -> object:
        clock = FakeClock()
        prober = FakeProber([Capabilities(hook_alive=True, mission_name="Someones Session")])
        self.launched = False

        def launcher(_exe: Path) -> FakeProcess:
            self.launched = True
            return FakeProcess()

        return run_unattended(
            _cfg(),
            launcher=launcher,
            prober=prober,
            hook_exec=lambda *a, **k: "ok",
            runner=lambda **_k: _passing_result(),
            sleeper=clock.sleep,
            clock=clock.now,
            allow_running=allow_running,
        )

    def test_refuses_a_running_instance_by_default(self) -> None:
        report = self._run(allow_running=False)
        self.assertIsNotNone(report.error)
        self.assertIn("already running", report.error or "")
        self.assertFalse(self.launched)
        self.assertFalse(report.launched)

    def test_uses_a_running_instance_when_told_to_and_does_not_quit_it(self) -> None:
        report = self._run(allow_running=True)
        self.assertIsNone(report.error, report.steps)
        self.assertFalse(self.launched, "must not launch a second DCS")
        self.assertFalse(report.launched, "we did not start it, so we must not own quitting it")
        self.assertFalse(report.quit_clean)


class TestFailuresStillTerminate(unittest.TestCase):
    def test_hook_never_answers_times_out_and_kills_the_launched_process(self) -> None:
        clock = FakeClock()
        process = FakeProcess(alive_polls=1000)  # never exits on its own
        report = run_unattended(
            _cfg(launch_timeout=10.0, quit_timeout=4.0, poll_interval=2.0),
            launcher=lambda _e: process,
            prober=FakeProber([Capabilities(hook_alive=False)]),
            hook_exec=lambda *a, **k: "x",
            runner=lambda **_k: _passing_result(),
            sleeper=clock.sleep,
            clock=clock.now,
        )
        self.assertIsNotNone(report.error)
        self.assertIn("did not answer the hook", report.error or "")
        self.assertTrue(report.launched)
        self.assertTrue(process.terminated or process.killed, "a launched DCS must not be left running")

    def test_load_failure_is_reported_and_the_process_is_terminated(self) -> None:
        clock = FakeClock()
        process = FakeProcess(alive_polls=0)

        def hook_exec(lua: str, **_k: object) -> object:
            if "load_mission" in lua:
                raise FiddleError("boom")
            return "quitting"

        report = run_unattended(
            _cfg(),
            launcher=lambda _e: process,
            prober=FakeProber([Capabilities(hook_alive=False), Capabilities(hook_alive=True)]),
            hook_exec=hook_exec,
            runner=lambda **_k: _passing_result(),
            sleeper=clock.sleep,
            clock=clock.now,
        )
        self.assertIsNotNone(report.error)
        self.assertIn("load_mission", report.error or "")
        self.assertIsNone(report.result)
        self.assertTrue(report.quit_clean or process.terminated)

    def test_a_failed_check_makes_the_run_exit_nonzero(self) -> None:
        clock = FakeClock()
        report = run_unattended(
            _cfg(),
            launcher=lambda _e: FakeProcess(alive_polls=0),
            prober=FakeProber(
                [
                    Capabilities(hook_alive=False),
                    Capabilities(hook_alive=True, mission_name=None),
                    Capabilities(hook_alive=True, mission_name="M"),
                ]
            ),
            hook_exec=lambda *a, **k: "quitting",
            runner=lambda **_k: Result(outcomes=[Outcome("bad", False, "returned 'no'")]),
            sleeper=clock.sleep,
            clock=clock.now,
        )
        self.assertIsNone(report.error)
        self.assertEqual(report.exit_code, 1)


class TestQuitKillsAStuckInstance(unittest.TestCase):
    def test_a_dcs_that_will_not_exit_is_killed(self) -> None:
        clock = FakeClock()
        process = FakeProcess(alive_polls=1000)
        report = run_unattended(
            _cfg(quit_timeout=4.0, poll_interval=2.0),
            launcher=lambda _e: process,
            prober=FakeProber(
                [
                    Capabilities(hook_alive=False),
                    Capabilities(hook_alive=True, mission_name=None),
                    Capabilities(hook_alive=True, mission_name="M"),
                ]
            ),
            hook_exec=lambda *a, **k: "quitting",
            runner=lambda **_k: _passing_result(),
            sleeper=clock.sleep,
            clock=clock.now,
        )
        self.assertFalse(report.quit_clean)
        self.assertTrue(process.terminated)


class TestFindDcsExecutable(unittest.TestCase):
    def test_none_when_no_install_dir(self) -> None:
        self.assertIsNone(find_dcs_executable(None))

    def test_none_when_nothing_there(self) -> None:
        self.assertIsNone(find_dcs_executable("/nonexistent/dcs/root"))

    def test_finds_bin_dcs_exe(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "bin").mkdir()
            exe = root / "bin" / "DCS.exe"
            exe.write_text("", encoding="utf-8")
            self.assertEqual(find_dcs_executable(d), exe)


if __name__ == "__main__":
    unittest.main()
