"""Tests for the checklist image generator and the runtime-catalogue reader."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.checklist_images import (
    _TICK_COLOR,
    ChecklistImages,
    _encode,
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
        return sum(1 for pixel in image.get_flattened_data() if pixel == _TICK_COLOR)

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

    def test_the_resource_key_is_deterministic_and_carries_no_digest(self):
        """The key the Lua asks for must not move when a label changes.

        Only the file name carries the content digest; the key is the stable handle
        ``a_out_picture`` is given, so a checklist edit must not touch the emitted Lua.
        """
        self.assertEqual("VEAF_MapKey_Assist_f16c_cold_start_0", resource_key("f16c-cold-start", 0))

    def test_the_file_name_carries_a_content_digest(self):
        name = image_filename("f16c-cold-start", 2, b"some png bytes")
        self.assertTrue(name.startswith("assist-f16c-cold-start-2-"), name)
        self.assertTrue(name.endswith(".png"), name)

    def test_file_names_are_one_per_state(self):
        images = render_checklist_images(_checklist(2), parse_runtime_catalog(CATALOG_LUA), "en")
        self.assertEqual(3, len(images.files))
        for state in range(3):
            self.assertTrue(
                any(name.startswith(f"assist-f16c-cold-start-{state}-") for name in images.files),
                f"no file for state {state} in {sorted(images.files)}",
            )

    def test_labels_are_resolved_through_i18n_not_emitted_as_keys(self):
        catalog = parse_runtime_catalog(CATALOG_LUA)
        translated = render_state("Cold start", ["MAIN PWR to MAIN PWR"], 0)
        raw = render_state("Cold start", ["assist.step1"], 0)
        self.assertNotEqual(list(translated.get_flattened_data()), list(raw.get_flattened_data()))

        images = render_checklist_images(_checklist(2), catalog, "en")
        expected = render_state("Cold start", ["assist.step0", "MAIN PWR to MAIN PWR"], 0)
        # step0 is not in the catalogue and stays literal; step1 is translated.
        from veaf_libs.checklist_images import _encode  # noqa: PLC0415

        # Reached through `file_names` rather than a literal: the name carries a digest of its own
        # bytes now, so hard-coding it would pin this test to the rendering rather than to the text.
        self.assertEqual(_encode(expected), images.files[images.file_names[0]])

    def test_width_follows_the_longest_line_within_bounds(self):
        from veaf_libs.checklist_images import MAX_IMAGE_WIDTH, MIN_IMAGE_WIDTH, image_width

        self.assertEqual(MIN_IMAGE_WIDTH, image_width("t", ["a"]))
        self.assertEqual(MAX_IMAGE_WIDTH, image_width("t", ["x" * 500]))

        # Between the bounds, the width tracks the content. The label length that gets
        # there is measured against the font actually available rather than hard-coded:
        # CI has no Arial and Pillow falls back to a much smaller bitmap font, where a
        # fixed pair of labels both land on the clamped floor and the assertion is
        # vacuously false.
        label = "x" * 20
        while image_width("t", [label]) <= MIN_IMAGE_WIDTH and len(label) < 400:
            label += "x" * 20
        self.assertLess(image_width("t", [label]), image_width("t", [label + "x" * 20]))

    def test_width_does_not_change_with_the_state(self):
        labels = ["one", "a much longer second line", "three"]
        widths = {render_state("Cold start", labels, state).width for state in range(4)}
        self.assertEqual(1, len(widths))

    def test_inline_translations_are_rendered_in_the_missions_language(self):
        from veaf_libs.checklists import parse_checklist

        checklist = parse_checklist(
            {
                "id": "inline",
                "title": {"fr": "Titre", "en": "Title"},
                "aircraft": ["F-16C_50"],
                "menu": "cold-start",
                "steps": [{"label": {"fr": "Batterie", "en": "Battery"}, "element": "PTR-X", "confirm": True}],
            },
            source="test.yaml",
        )
        english = render_checklist_images(checklist, {}, "en")
        french = render_checklist_images(checklist, {}, "fr")
        self.assertNotEqual(english.files[english.file_names[0]], french.files[french.file_names[0]])
        # And neither renders the mapping itself.
        self.assertEqual(english.files[english.file_names[0]], _encode(render_state("Title", ["Battery"], 0)))

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


class TestContentAddressedNames(unittest.TestCase):
    """The file name changes when the picture does — FEAT-ASSIST-FOLLOWUP ticket 01.

    DCS caches embedded resources **by name**. During the first checklist flight the image for
    state 0 showed raw i18n keys while every later state was translated: the ``.miz`` was innocent
    (all seven PNGs matched a fresh render byte for byte), but state 0 was the only one already
    *displayed* under an earlier build, so DCS served its cached bitmap. A full restart cleared it.

    The symptom — "the text is wrong, but only on the first image" — points nowhere near the cause,
    and it hits any mission maker iterating on a checklist, not just whoever wrote the engine.
    """

    def _render(self, labels: list[str]):
        checklist = parse_checklist(
            {
                "id": "f16c-cold-start",
                "title": "Cold start",
                "aircraft": ["F-16C_50"],
                "menu": "cold-start",
                "steps": [{"label": label, "element": "PTR-X"} for label in labels],
            },
            source="test.yaml",
        )
        return render_checklist_images(checklist, parse_runtime_catalog(CATALOG_LUA), "en")

    def test_identical_content_gives_identical_names(self):
        """No churn in the .miz when nothing changed."""
        first = self._render(["one", "two"])
        second = self._render(["one", "two"])
        self.assertEqual(sorted(first.files), sorted(second.files))

    def test_a_changed_label_changes_the_name(self):
        """The whole point: DCS cannot serve a stale bitmap under a new name."""
        before = self._render(["one", "two"])
        after = self._render(["one", "CHANGED"])
        self.assertNotEqual(sorted(before.files), sorted(after.files))

    def test_the_resource_keys_do_not_move_when_a_label_changes(self):
        """The Lua side is untouched by a checklist edit."""
        before = self._render(["one", "two"])
        after = self._render(["one", "CHANGED"])
        self.assertEqual(before.resource_keys, after.resource_keys)

    def test_the_mapping_points_at_the_files_that_exist(self):
        """`resources()` used to rebuild names from the id and state, which a digest makes impossible.

        If it drifts from ``files``, ``mapResource`` names a file the archive does not contain — and
        the DCS editor prunes what its resource table does not declare, which is the shape
        FIX-COMMUNITY-SOUNDS-PRUNED had to repair.
        """
        images = self._render(["one", "two", "three"])
        self.assertEqual(sorted(images.resources().values()), sorted(images.files))

    def test_every_state_maps_to_its_own_picture(self):
        """Pairing by state index, not by sorted name: ...-10 must not land between ...-1 and ...-2."""
        images = self._render([f"step {index}" for index in range(11)])
        mapping = images.resources()
        self.assertEqual(12, len(mapping))
        for state, key in enumerate(images.resource_keys):
            self.assertTrue(
                mapping[key].startswith(f"assist-f16c-cold-start-{state}-"),
                f"state {state} maps to {mapping[key]}",
            )

    def test_two_builds_with_different_labels_share_no_file_name(self):
        """The orphan question, asserted rather than assumed.

        A per-build name would leave the previous picture behind if the archive were written on top
        of itself. It is not: ``create_miz`` rebuilds the ``.miz`` from ``src/`` on every build, and
        the images only enter afterwards through ``write_miz``'s ``additional_files`` — so the file
        names of a previous build are never in the archive being copied. This asserts the premise
        that makes that safe, namely that a changed label really does produce a distinct name.
        """
        before = set(self._render(["one", "two"]).files)
        after = set(self._render(["ONE", "TWO"]).files)
        self.assertEqual(set(), before & after)


class TestPairingInvariant(unittest.TestCase):
    """A ChecklistImages that cannot be paired must not exist — Sourcery on #718.

    `resources()` indexes `file_names` by the position of a key. Two lists of different lengths
    either raise deep inside a caller or, worse, pair a state with another state's picture and say
    nothing — which is how `mapResource` comes to name the wrong file.
    """

    def test_a_mismatched_pair_is_refused_at_construction(self):
        with self.assertRaises(ValueError) as caught:
            ChecklistImages(
                checklist_id="f16c-cold-start",
                resource_keys=["k0", "k1"],
                file_names=["only-one.png"],
                files={"only-one.png": b"x"},
            )
        # The message has to name the checklist and both counts, or it sends the reader hunting.
        self.assertIn("f16c-cold-start", str(caught.exception))
        self.assertIn("2 resource keys", str(caught.exception))
        self.assertIn("1 file names", str(caught.exception))

    def test_a_matched_pair_is_accepted(self):
        images = ChecklistImages(
            checklist_id="f16c-cold-start",
            resource_keys=["k0"],
            file_names=["a.png"],
            files={"a.png": b"x"},
        )
        self.assertEqual({"k0": "a.png"}, images.resources())
