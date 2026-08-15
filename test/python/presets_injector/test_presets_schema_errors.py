"""The presets loader must say what is wrong — FIX-CONVERT-V5-PRESETS-SCHEMA ticket 01.

What a mission maker used to get, converting a v5 mission whose `src/presets.yaml` kept the v5
layout:

    Error loading presets from D:\\…\\src\\presets.yaml: 'dict' object has no attribute 'lower'

No key, no expectation, no hint that the cause is one extra nesting level. And underneath it, a
loader that drops every top-level key it does not recognise **in silence**, which is how a renamed
block (`presets_definition` → `presets_collection`) surfaced one step later as an error accusing the
one part of the file that was correct.

These tests assert the messages, not just that something is raised: the message *is* the fix.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from presets_injector.presets_manager import PresetsManager
from veaf_libs.i18n import language


def _load(yaml_text: str) -> str:
    """Load a presets file and return the error message, or '' when it loaded cleanly.

    Pinned to English: these assertions are about the **wording** of the English catalogue, and
    would otherwise pass or fail depending on the machine's locale.
    """
    path = Path(tempfile.mkdtemp()) / "presets.yaml"
    path.write_text(yaml_text, encoding="utf-8")
    try:
        with language("en"):
            PresetsManager().read_yaml(path)
    except Exception as exc:  # the loader wraps everything, including the file path
        return str(exc)
    return ""


#: The v6 layout, minimal but complete: channels are named, radios reference channel names, presets
#: reference radio names, assignments reference preset names.
_HEAD = """
channels_collection:
  tactical:
    Guard:
      title: Guard
      freqs:
        uhf: 243
        vhf: 121.5

radios_collection:
  blue_radios:
    radio_uhf:
      title: UHF
      type: uhf
      channels:
        01:
          title: Guard/UHF
          channel: Guard

presets_collection:
  blue_presets:
    modern_blue:
      title: Blue
      radios:
        radio_1: radio_uhf
"""

_VALID = (
    _HEAD
    + """
presets_assignments:
  blue:
    plane:
      all: modern_blue
"""
)

#: The same file with the v5 `coalitions:` level the converter leaves in place.
_V5_ASSIGNMENTS = (
    _HEAD
    + """
presets_assignments:
  coalitions:
    blue:
      plane:
        all: modern_blue
"""
)


class TestHappyPathUnchanged(unittest.TestCase):
    def test_a_valid_v6_file_still_loads(self) -> None:
        self.assertEqual(_load(_VALID), "")

    def test_assignments_are_actually_read(self) -> None:
        path = Path(tempfile.mkdtemp()) / "presets.yaml"
        path.write_text(_VALID, encoding="utf-8")
        manager = PresetsManager()
        manager.read_yaml(path)
        assignment = manager.preset_assignments.get_preset_for(
            coalition="blue", aircraft_type="plane", unit_type="F-16C_50"
        )
        self.assertIsNotNone(assignment)


class TestV5AssignmentsAreDiagnosed(unittest.TestCase):
    """The extra `coalitions:` level is the v5 layout, and the message must say so."""

    def test_names_the_v5_layout(self) -> None:
        message = _load(_V5_ASSIGNMENTS)
        self.assertIn("coalitions", message)
        self.assertIn("v5", message.lower())

    def test_says_what_to_do_about_it(self) -> None:
        # A diagnosis with no remedy still leaves the maker stuck.
        message = _load(_V5_ASSIGNMENTS).lower()
        self.assertTrue(
            "remove" in message or "un-indent" in message or "convert-v5" in message,
            f"the message must say how to fix it, got: {message}",
        )

    def test_no_attribute_error_wording_survives(self) -> None:
        message = _load(_V5_ASSIGNMENTS)
        self.assertNotIn("has no attribute", message)


class TestLeafShapeIsChecked(unittest.TestCase):
    """Whatever the leaf turns out to be, the message names the key and the expectation."""

    def _assignments(self, leaf: str) -> str:
        return _VALID.replace("      all: modern_blue", f"      all: {leaf}")

    def test_a_list_leaf_is_reported_with_its_key_path(self) -> None:
        message = _load(self._assignments("[modern_blue, modern_red]"))
        self.assertIn("presets_assignments", message)
        self.assertIn("blue", message)
        self.assertIn("plane", message)
        self.assertIn("all", message)
        self.assertNotIn("has no attribute", message)

    def test_a_number_leaf_is_reported(self) -> None:
        message = _load(self._assignments("42"))
        self.assertNotEqual(message, "")
        self.assertNotIn("has no attribute", message)

    def test_an_empty_leaf_is_reported(self) -> None:
        message = _load(self._assignments("null"))
        self.assertNotEqual(message, "")
        self.assertNotIn("has no attribute", message)

    def test_a_coalition_that_is_not_a_mapping_is_reported(self) -> None:
        message = _load(_VALID.replace("  blue:\n    plane:\n      all: modern_blue", "  blue: modern_blue"))
        self.assertIn("blue", message)
        self.assertNotIn("has no attribute", message)


class TestUnknownTopLevelKeys(unittest.TestCase):
    """A section the loader does not know must not be dropped in silence."""

    def test_the_v5_definitions_key_is_reported_with_its_near_miss(self) -> None:
        # `presets_definition` is what v5 called `presets_collection`. Dropping it silently made the
        # failure surface as "preset modern_blue was not found in any PresetCollection" — an error
        # about the assignments, which were fine.
        message = _load(_VALID.replace("presets_collection:", "presets_definition:"))
        self.assertIn("presets_definition", message)
        self.assertIn("presets_collection", message, "the near-miss is the whole value of the message")

    def test_an_unrelated_unknown_key_is_reported(self) -> None:
        message = _load(_VALID + "\nwhat_is_this:\n  foo: bar\n")
        self.assertIn("what_is_this", message)

    def test_a_comment_only_addition_does_not_trip_it(self) -> None:
        self.assertEqual(_load(_VALID + "\n# just a comment\n"), "")


class TestPresetCollectionShape(unittest.TestCase):
    """`presets_collection` has two levels in v6 where v5 had one."""

    def test_a_v5_preset_block_names_the_missing_collection_level(self) -> None:
        # v5: presets_definition.<preset>. v6: presets_collection.<collection>.<preset>. So a v5
        # file presents a preset's own `title` where a preset name is expected, and the value is a
        # plain string — which used to read as `'str' object has no attribute 'get'`.
        v5 = _HEAD.replace(
            """presets_collection:
  blue_presets:
    modern_blue:
      title: Blue
      radios:
        radio_1: radio_uhf
""",
            """presets_collection:
  modern_blue:
    title: Blue
    radios:
      radio_1: radio_uhf
""",
        )
        message = _load(v5)
        self.assertIn("presets_collection.modern_blue.title", message)
        self.assertIn("two levels", message)
        self.assertNotIn("has no attribute", message)

    def test_inline_radios_are_diagnosed_as_the_v5_layout(self) -> None:
        inline = _VALID.replace(
            "        radio_1: radio_uhf",
            "        radio_1:\n          title: UHF\n          channels:\n            01: Guard",
        )
        message = _load(inline)
        self.assertIn("radios_collection", message)
        self.assertIn("v5", message.lower())
        # and it must not dump the whole block at the reader
        self.assertNotIn("'channels':", message)

    def test_an_unknown_radio_name_lists_what_exists(self) -> None:
        message = _load(_VALID.replace("radio_1: radio_uhf", "radio_1: radio_uhff"))
        self.assertIn("radio_uhff", message)
        self.assertIn("radio_uhf", message)
        self.assertNotIn("class PresetDefinition", message, "parser vocabulary, not a mission maker's")


class TestFileLevelProblems(unittest.TestCase):
    def test_an_empty_file_is_reported_rather_than_crashing(self) -> None:
        message = _load("")
        self.assertNotEqual(message, "")
        self.assertNotIn("has no attribute", message)
        self.assertNotIn("NoneType", message, "the message is for a mission maker, not a traceback")

    def test_a_top_level_list_is_reported(self) -> None:
        message = _load("- one\n- two\n")
        self.assertNotEqual(message, "")
        self.assertNotIn("has no attribute", message)


if __name__ == "__main__":
    unittest.main()
