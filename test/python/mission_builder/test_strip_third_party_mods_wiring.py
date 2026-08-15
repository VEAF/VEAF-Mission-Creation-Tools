"""Worker wiring for third-party-mod stripping (FEAT-THIRD-PARTY-MODS-002)."""

from __future__ import annotations

from types import SimpleNamespace

from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_builder_factory import make_worker


def _worker(mission_content: dict, mission_yaml: dict) -> MissionBuilderWorker:
    """A worker shell carrying only what strip_third_party_mod_requirements needs."""
    return make_worker(
        dcs_mission=SimpleNamespace(mission_content=mission_content),
        mission_yaml=mission_yaml,
    )


class TestStripThirdPartyModRequirementsWiring:
    def test_applies_the_default_list_with_no_config(self) -> None:
        content = {"requiredModules": {"Hercules": "Hercules", "F-16C": "F-16C"}}
        worker = _worker(content, {})

        worker.strip_third_party_mod_requirements(silent=True)

        assert content["requiredModules"] == {"F-16C": "F-16C"}

    def test_unions_mission_third_party_mods_with_the_default(self) -> None:
        content = {"requiredModules": {"Hercules": "Hercules", "MyMod": "MyMod", "F-16C": "F-16C"}}
        worker = _worker(content, {"mission": {"third_party_mods": ["MyMod"]}})

        worker.strip_third_party_mod_requirements(silent=True)

        assert content["requiredModules"] == {"F-16C": "F-16C"}

    def test_no_dcs_mission_is_a_noop(self) -> None:
        worker = make_worker(dcs_mission=None, mission_yaml={})

        worker.strip_third_party_mod_requirements(silent=True)  # must not raise
