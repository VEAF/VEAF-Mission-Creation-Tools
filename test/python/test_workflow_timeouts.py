"""Every CI job, and every apt-get step, carries a timeout (CHORE-CI-JOB-TIMEOUTS).

On 2026-10-22 a `python-quality` job hung four hours in `apt-get update` (a mirror that stopped
answering): with no `timeout-minutes`, GitHub keeps a job for its default six hours, a runner with it,
and a pull request whose required check it is.
"""

from pathlib import Path

import pytest
import yaml

WORKFLOWS = sorted((Path(__file__).resolve().parents[2] / ".github" / "workflows").glob("*.yml"))


def _jobs(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))["jobs"]


def test_there_are_workflows_to_check() -> None:
    assert len(WORKFLOWS) > 5


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: p.name)
def test_every_job_has_a_timeout(path: Path) -> None:
    missing = [name for name, job in _jobs(path).items() if "timeout-minutes" not in job]
    assert not missing, f"{path.name}: no timeout-minutes on {missing}"


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: p.name)
def test_every_apt_step_has_its_own_timeout(path: Path) -> None:
    missing = [
        f"{name}: {step.get('name')}"
        for name, job in _jobs(path).items()
        for step in job.get("steps", [])
        if "apt-get" in str(step.get("run", "")) and "timeout-minutes" not in step
    ]
    assert not missing, f"{path.name}: no step timeout-minutes on {missing}"
