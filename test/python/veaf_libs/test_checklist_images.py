"""Tests for the checklist image generator and the runtime-catalogue reader."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.checklist_images import (
    _TICK_COLOR,
    image_filename,
    line_states,
    render_all,
    render_checklist_images,
    render_state,
    resource_key,
)
from veaf_libs.checklists import parse_checklist
from veaf_libs.lua_config_generator import generate_config_lua
from veaf_libs.lua_i18n import (
    find_runtime_catalog,
    load_runtime_catalog,
    parse_runtime_catalog,
    translate,
)

CATALOG_LUA = """
veaf.i18nCatalog = {
  ["assist.title"] = {
    fr = "Démarrage à froid",
    en = "Cold start",
  },
  ["assist.step1"] = {
    fr = "MAIN PWR sur MAIN PWR",
    en = "MAIN PWR to MAIN PWR",
  },
  ["assist.step2"] = {
    fr = "Dites \\"go\\"",
    en = "Say \\"go\\"",
  },
  ["assist.fr_only"] = {
    fr = "Seulement en français",
  },
}
"""


def _checklist(step_count: int) -> object:
    """Return a parsed checklist with *step_count* confirm steps."""
    return parse_checklist(
        {
            "id": "f16c-cold-start",
            "title": "assist.title",
            "aircraft": ["F-16C_50"],
            "menu": "cold-start",
            "steps": [{"label": f"assist.step{index}", "element": "PTR-X"} for index in range(step_count)],
        },
        source="test.yaml",
    )


class TestRuntimeCatalog(unittest.TestCase):
    """Reading veafI18n.lua from the design-time tools."""

    def test_entries_are_parsed(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        self.assertEqual({"fr": "Démarrage à froid", "en": "Cold start"}, catalog["assist.title"])

    def test_escaped_quotes_are_unescaped(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        self.assertEqual('Say "go"', catalog["assist.step2"]["en"])

    def test_translate_uses_the_requested_language(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        self.assertEqual("Cold start", translate(catalog, "assist.title", "en"))
        self.assertEqual("Démarrage à froid", translate(catalog, "assist.title", "fr"))

    def test_translate_falls_back_to_french_then_to_the_key(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        self.assertEqual("Seulement en français", translate(catalog, "assist.fr_only", "en"))
        self.assertEqual("plain text", translate(catalog, "plain text", "en"))

    def test_catalogue_is_found_and_read_from_a_scripts_folder(self):
        with TemporaryDirectory() as tmp:
            scripts = Path(tmp) / "src" / "scripts" / "veaf"
            scripts.mkdir(parents=True)
            (scripts / "veafI18n.lua").write_text(CATALOG_LUA, encoding="utf-8")

            self.assertIsNotNone(find_runtime_catalog(Path(tmp)))
            self.assertIn("assist.title", load_runtime_catalog(Path(tmp)))

    def test_absent_catalogue_reads_as_empty(self):
        with TemporaryDirectory() as tmp:
            self.assertIsNone(find_runtime_catalog(Path(tmp)))
            self.assertEqual({}, load_runtime_catalog(Path(tmp)))

    def test_the_shipped_catalogue_parses(self):
        shipped = Path(__file__).resolve().parents[3] / "src" / "scripts" / "veaf" / "veafI18n.lua"
        catalog = parse_runtime_catalog(shipped.read_text(encoding="utf-8"))
        self.assertGreater(len(catalog), 200)
        self.assertTrue(all("fr" in entry for entry in catalog.values()))


class TestProgressStates(unittest.TestCase):
    """Which line is ticked, current and pending in a given state."""

    def test_first_state_has_no_tick_and_a_current_first_line(self):
        self.assertEqual(["current", "pending", "pending"], line_states(3, 0))

    def test_middle_state_ticks_the_lines_walked(self):
        self.assertEqual(["done", "done", "current"], line_states(3, 2))

    def test_final_state_ticks_everything(self):
        self.assertEqual(["done", "done", "done"], line_states(3, 3))


class TestRendering(unittest.TestCase):
    """The generated images."""

    def _green_pixels(self, state: int, labels: list[str]) -> int:
        image = render_state("Cold start", labels, state)
        return sum(1 for pixel in image.getdata() if pixel == _TICK_COLOR)

    def test_n_steps_produce_n_plus_one_images(self):
        images = render_checklist_images(_checklist(4), parse_runtime_catalog(CATALOG_LUA), "en")
        self.assertEqual(5, len(images.files))
        self.assertEqual(5, len(images.resource_keys))

    def test_tick_count_grows_with_the_state(self):
        labels = ["one", "two", "three"]
        counts = [self._green_pixels(state, labels) for state in range(4)]
        self.assertEqual(0, counts[0])
        self.assertLess(counts[1], counts[2])
        self.assertLess(counts[2], counts[3])
        # Ticks are identical, so their pixel count is exactly proportional.
        self.assertEqual(counts[1] * 3, counts[3])

    def test_resource_names_are_deterministic(self):
        self.assertEqual("VEAF_MapKey_Assist_f16c_cold_start_0", resource_key("f16c-cold-start", 0))
        self.assertEqual("assist-f16c-cold-start-2.png", image_filename("f16c-cold-start", 2))

    def test_file_names_match_the_states(self):
        images = render_checklist_images(_checklist(2), parse_runtime_catalog(CATALOG_LUA), "en")
        self.assertEqual(
            ["assist-f16c-cold-start-0.png", "assist-f16c-cold-start-1.png", "assist-f16c-cold-start-2.png"],
            sorted(images.files),
        )

    def test_labels_are_resolved_through_i18n_not_emitted_as_keys(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        translated = render_state("Cold start", ["MAIN PWR to MAIN PWR"], 0)
        raw = render_state("Cold start", ["assist.step1"], 0)
        self.assertNotEqual(list(translated.getdata()), list(raw.getdata()))

        images = render_checklist_images(_checklist(2), catalog, "en")
        expected = render_state("Cold start", ["assist.step0", "MAIN PWR to MAIN PWR"], 0)
        # step0 is not in the catalogue and stays literal; step1 is translated.
        from veaf_libs.checklist_images import _encode  # noqa: PLC0415

        self.assertEqual(_encode(expected), images.files["assist-f16c-cold-start-0.png"])

    def test_width_follows_the_longest_line_within_bounds(self):
        from veaf_libs.checklist_images import MAX_IMAGE_WIDTH, MIN_IMAGE_WIDTH, image_width

        self.assertEqual(MIN_IMAGE_WIDTH, image_width("t", ["a"]))
        self.assertEqual(MAX_IMAGE_WIDTH, image_width("t", ["x" * 500]))
        self.assertLess(
            image_width("t", ["a step label long enough to pass the floor"]),
            image_width("t", ["a step label long enough to pass the floor, and then quite a bit more"]),
        )

    def test_width_does_not_change_with_the_state(self):
        labels = ["one", "a much longer second line", "three"]
        widths = {render_state("Cold start", labels, state).width for state in range(4)}
        self.assertEqual(1, len(widths))

    def test_indexed_png_stays_small(self):
        images = render_checklist_images(_checklist(12), parse_runtime_catalog(CATALOG_LUA), "en")
        self.assertTrue(all(len(payload) < 30_000 for payload in images.files.values()))

    def test_render_all_returns_one_entry_per_checklist(self):
        rendered = render_all([_checklist(2)], parse_runtime_catalog(CATALOG_LUA), "en")
        self.assertEqual(1, len(rendered))
        self.assertGreater(rendered[0].total_bytes, 0)

    def test_render_all_of_nothing_is_empty(self):
        self.assertEqual([], render_all([], {}, "en"))


class TestImageKeysEmission(unittest.TestCase):
    """The resource keys reach the Lua the engine reads."""

    def test_image_keys_are_emitted_into_the_checklist_table(self):
        checklist = _checklist(2)
        images = render_checklist_images(checklist, parse_runtime_catalog(CATALOG_LUA), "en")
        lua = generate_config_lua(
            {"lua_modules": {"ASSIST": {}}},
            checklists=[checklist],
            checklist_images={images.checklist_id: images.resource_keys},
        )
        self.assertIn(
            'images = {"VEAF_MapKey_Assist_f16c_cold_start_0", '
            '"VEAF_MapKey_Assist_f16c_cold_start_1", '
            '"VEAF_MapKey_Assist_f16c_cold_start_2"}',
            lua,
        )

    def test_no_images_means_no_images_field(self):
        lua = generate_config_lua({"lua_modules": {"ASSIST": {}}}, checklists=[_checklist(2)])
        self.assertIn("registerChecklist", lua)
        self.assertNotIn("images = ", lua)


if __name__ == "__main__":
    unittest.main()
