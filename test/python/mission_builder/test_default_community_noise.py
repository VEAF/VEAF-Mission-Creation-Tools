"""FIX-DEFAULT-COMMUNITY-NOISE: a message about a script the mission never named.

Community scripts are opt-out, so a ``mission.yaml`` with no ``community_scripts:``
section — which is what ``veaf-tools prepare --template minimal`` writes, since
``render_modules_block`` simply omits the modules a tier does not enable — has CTLD
enabled without ever mentioning it. The build then finds no ``ctld-config.yaml`` and
says so, and the reader has no way to connect that to anything they wrote.

Nothing pinned that message before this lot, which is why it could read as "you have
already broken something" all the way into the tutorial (PR #863).

Every test here goes through the **real constructor** on a **real mission folder**:
what broke was the wiring between "no section in ``mission.yaml``" and what the
mission maker is told, not the message-emitting branch. A hand-built worker shell can
be given a ``mission_yaml`` and an ``enabled_community_script_ids`` that disagree, and
would prove nothing.
"""

from __future__ import annotations

import tempfile
import unittest
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from mission_builder.mission_builder_worker import CTLD_CONFIG_FILENAME, MissionBuilderWorker
from veaf_libs.i18n import current_language, set_language

_LOGGER = "veaf-tools"

#: A `modules:` block with no community script in it — the shape `prepare --template
#: minimal` writes, and the shape the tutorial built from.
_MINIMAL_MODULES = "modules:\n  UNITS:\n  TIME:\n  CACHE:\n  EVENTS:\n  MARKERS:\n  COMMANDS:\n"


@contextmanager
def _language(lang: str) -> Iterator[None]:
    """Run the block with the catalogue forced to *lang*, then restore the ambient one."""
    previous = current_language()
    set_language(lang)
    try:
        yield
    finally:
        set_language(previous)


def _worker(yaml_content: str) -> MissionBuilderWorker:
    """A worker built by the real constructor over a folder holding *yaml_content*.

    The folder outlives the call (``mkdtemp``, not ``TemporaryDirectory``): the branch
    under test reads ``ctld-config.yaml`` from it.
    """
    mission_dir = Path(tempfile.mkdtemp())
    (mission_dir / "mission.yaml").write_text(yaml_content, encoding="utf-8")
    return MissionBuilderWorker(
        mission_folder=mission_dir,
        output_mission=mission_dir / "out.miz",
        dynamic_mode=None,
    )


def _build_message(yaml_content: str, lang: str = "en") -> str:
    """Return everything the CTLD configuration step logged, in *lang*."""
    worker = _worker(yaml_content)
    case = unittest.TestCase()
    with _language(lang), case.assertLogs(_LOGGER, level="INFO") as captured:
        worker._ctld_user_config_lua()
    return "\n".join(captured.output)


class TestCtldReallyIsEnabled(unittest.TestCase):
    """The premise: with no section, CTLD is on. The message was never inaccurate."""

    def test_a_modules_block_without_ctld_still_enables_it(self) -> None:
        self.assertTrue(_worker(_MINIMAL_MODULES)._community_enabled("ctld"))

    def test_and_the_configuration_lua_is_still_generated(self) -> None:
        worker = _worker(_MINIMAL_MODULES)
        with self.assertLogs(_LOGGER, level="INFO"):
            lua = worker._ctld_user_config_lua()
        assert lua is not None
        self.assertIn("ctld.dontInitialize = true", lua)


class TestMessageWhenTheMissionNeverNamedCtld(unittest.TestCase):
    """The defaulted case gets a message that explains itself."""

    def test_it_says_how_to_turn_ctld_off(self) -> None:
        """The only action this reader wants is the opt-out, in both languages."""
        for lang in ("en", "fr"):
            with self.subTest(lang=lang):
                self.assertIn("CTLD: false", _build_message(_MINIMAL_MODULES, lang))

    def test_it_says_why_ctld_is_on(self) -> None:
        """`Enabled by whom?` is the whole complaint — the answer is in the message."""
        self.assertIn("by default", _build_message(_MINIMAL_MODULES, "en").lower())
        self.assertIn("par défaut", _build_message(_MINIMAL_MODULES, "fr").lower())

    def test_it_does_not_send_a_beginner_off_to_download_a_tool(self) -> None:
        """Nothing is broken here, so nothing points at ctld-tools.exe."""
        for lang in ("en", "fr"):
            with self.subTest(lang=lang):
                self.assertNotIn("ctld-tools.exe", _build_message(_MINIMAL_MODULES, lang))

    def test_an_empty_mission_yaml_is_the_defaulted_case_too(self) -> None:
        self.assertIn("CTLD: false", _build_message(""))

    def test_naming_another_community_script_does_not_count(self) -> None:
        self.assertIn("CTLD: false", _build_message("modules:\n  CSAR: true\n"))


class TestMessageWhenTheMissionAskedForCtld(unittest.TestCase):
    """A mission that named CTLD keeps the actionable message, unchanged."""

    def test_explicit_true_points_at_ctld_tools(self) -> None:
        message = _build_message("modules:\n  CTLD: true\n")
        self.assertIn("ctld-tools.exe", message)
        self.assertNotIn("CTLD: false", message)

    def test_a_configuration_block_counts_as_naming_it(self) -> None:
        """`CTLD: { manage_logistics: true }` is a choice even with no `enabled:` key."""
        yaml = "modules:\n  CTLD:\n    enabled: true\n    manage_logistics: true\n"
        self.assertIn("ctld-tools.exe", _build_message(yaml))

    def test_a_legacy_lowercase_section_counts_too(self) -> None:
        """`community_scripts:` is hand-written and its keys are not case-normalised."""
        self.assertIn("ctld-tools.exe", _build_message("community_scripts:\n  ctld: true\n"))

    def test_the_french_message_is_the_actionable_one_as_well(self) -> None:
        self.assertIn("ctld-tools.exe", _build_message("modules:\n  CTLD: true\n", "fr"))


class TestSilenceWhereSilenceIsRight(unittest.TestCase):
    """Two cases must say nothing at all."""

    def test_ctld_turned_off_generates_nothing_and_says_nothing(self) -> None:
        worker = _worker("modules:\n  CTLD: false\n")
        with self.assertNoLogs(_LOGGER, level="INFO"):
            self.assertIsNone(worker._ctld_user_config_lua())

    def test_a_mission_with_a_configuration_is_never_told_it_is_missing_one(self) -> None:
        worker = _worker(_MINIMAL_MODULES)
        (worker.mission_folder / CTLD_CONFIG_FILENAME).write_text(
            'configVersion: "2.0.0"\nlogisticUnitTypes: []\ntroopZoneShipTypes: []\n', encoding="utf-8"
        )
        lua = worker._ctld_user_config_lua()
        assert lua is not None
        self.assertIn("ctld.configUser", lua)


if __name__ == "__main__":
    unittest.main()
