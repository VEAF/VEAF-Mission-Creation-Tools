"""The 2:3 presets kneeboard page and the calibration page (FEAT-KNEEBOARD-PRESETS-REDESIGN).

DCS stretches a kneeboard image onto the whole window, so these tests pin what the page owes the
pilot: its size, the headings and rows of each radio block, how blocks flow into columns and
pages, the page paths, and the calibration page that comes with them.
"""

import io
import unittest
from unittest import mock

from PIL import Image, ImageDraw
from presets_injector.presets_manager import (
    _BLOCK_GAP,
    _BLOCK_HEAD_H,
    _COLUMN_H,
    _ROW_H,
    KNEEBOARD_CALIBRATION_PATH,
    KNEEBOARD_PAGE_SIZE,
    Channel,
    KneeboardBlock,
    KneeboardRow,
    PresetDefinition,
    PresetsManager,
    RadioDefinition,
    RadioLayoutRadio,
    RadioPresetsImageGenerator,
    _format_freq,
    _kneeboard_blocks,
    _kneeboard_rows,
    _load_radio_layouts,
    _paginate_blocks,
    _radio_band,
    _radio_heading,
    get_radio_layout,
    parse_radio_layouts,
    render_calibration_page,
)
from presets_injector.radio_frequency_validator import FrequencyRange, RadioSpec, get_aircraft_name
from veaf_libs.i18n import set_language


def _radio(name: str, *channels: Channel, title: str = "UHF") -> RadioDefinition:
    radio = RadioDefinition(name=name, radio_type="uhf", title=title)
    for channel in channels:
        radio.add_channel(channel)
    return radio


def _preset(*radios: RadioDefinition) -> PresetDefinition:
    preset = PresetDefinition(name="p", title="t")
    for radio in radios:
        preset.add_radio(radio)
    return preset


def _filled(name: str, count: int, base: float = 250.0) -> RadioDefinition:
    return _radio(name, *(Channel(slot, base + slot, title=f"C{slot}") for slot in range(1, count + 1)))


def _block(rows: int) -> KneeboardBlock:
    return KneeboardBlock(
        title="b", band="", show_mod=False, rows=[KneeboardRow(f"{i:02d}", None) for i in range(rows)]
    )


def _open(buffer: io.BytesIO) -> Image.Image:
    return Image.open(io.BytesIO(buffer.getvalue()))


class TestPageSize(unittest.TestCase):
    """Every page is the 2:3 portrait of the kneeboard window."""

    def test_the_size_is_two_by_three(self) -> None:
        width, height = KNEEBOARD_PAGE_SIZE
        self.assertEqual(width * 3, height * 2)

    def test_every_presets_page_has_that_size(self) -> None:
        injected = {
            ("blue", "A-10C_2"): _preset(_filled("r1", 9), _filled("r2", 20), _filled("r3", 30, base=30.0)),
            ("blue", "UH-1H"): _preset(_filled("r1", 3)),
        }
        images = RadioPresetsImageGenerator({}).generate_type_images(injected)
        self.assertTrue(images)
        for path, buffer in images.items():
            with self.subTest(path=path):
                self.assertEqual(_open(buffer).size, KNEEBOARD_PAGE_SIZE)

    def test_the_calibration_page_has_that_size(self) -> None:
        self.assertEqual(_open(render_calibration_page()).size, KNEEBOARD_PAGE_SIZE)


class TestRadioHeading(unittest.TestCase):
    def test_the_specs_name_reads_set_then_model(self) -> None:
        spec = RadioSpec(name="COMM 1: ARC-210", ranges=[])
        self.assertEqual(_radio_heading(1, spec, None, _radio("r")), "1. COMM 1 · ARC-210")

    def test_a_name_without_model_stays_whole(self) -> None:
        spec = RadioSpec(name="R-863", ranges=[])
        self.assertEqual(_radio_heading(2, spec, None, _radio("r")), "2. R-863")

    def test_the_layout_title_wins_over_the_specs(self) -> None:
        spec = RadioSpec(name="Radio frequencies", ranges=[])
        layout_radio = RadioLayoutRadio(role="primary_1", kneeboard_title="FR22 / FR24")
        self.assertEqual(_radio_heading(1, spec, layout_radio, _radio("r")), "1. FR22 / FR24")

    def test_an_unknown_type_falls_back_to_the_radio_title(self) -> None:
        self.assertEqual(_radio_heading(1, None, None, _radio("r", title="UHF")), "1. UHF")

    def test_the_band_spans_every_range(self) -> None:
        spec = RadioSpec(
            name="x",
            ranges=[FrequencyRange(225.0, 399.975, "AM"), FrequencyRange(30.0, 87.975, "FM")],
        )
        self.assertEqual(_radio_band(spec), "30–399.975 MHz")
        self.assertEqual(_radio_band(None), "")


class TestBlocksFromTheSpecs(unittest.TestCase):
    """The headings come from the real specs and layouts, by physical position."""

    def test_the_a10c2_radios_carry_their_cockpit_sets(self) -> None:
        preset = _preset(_filled("r1", 1), _filled("r2", 1), _filled("r3", 1, base=30.0))
        titles = [block.title for block in _kneeboard_blocks("A-10C_2", preset)]
        self.assertEqual(titles[:2], ["1. UHF/VHF · ARC-210", "2. UHF AM · ARC-164"])

    def test_the_viggen_reads_fr22_fr24(self) -> None:
        self.assertEqual(_kneeboard_blocks("AJS37", _preset(_filled("r1", 1)))[0].title, "1. FR22 / FR24")

    def test_the_viggen_layout_carries_its_kneeboard_title(self) -> None:
        layout = get_radio_layout(_load_radio_layouts(), "AJS37")
        assert layout is not None
        self.assertEqual(layout.radios[1].kneeboard_title, "FR22 / FR24")

    def test_a_layout_without_kneeboard_title_parses_to_none(self) -> None:
        layouts = parse_radio_layouts({"X": {"radios": {1: {"role": "primary_1"}}}})
        self.assertIsNone(layouts["X"].radios[1].kneeboard_title)

    def test_a_radio_with_no_channel_draws_no_block(self) -> None:
        self.assertEqual(_kneeboard_blocks("UH-1H", _preset(_radio("empty"))), [])

    def test_the_mod_column_shows_only_for_a_mixed_radio(self) -> None:
        mixed = _radio("m", Channel(1, 251.0, mod=0), Channel(2, 33.0, mod=1))
        plain = _radio("p", Channel(1, 251.0, mod=0), Channel(2, 252.0))
        blocks = _kneeboard_blocks("UNKNOWN-TYPE", _preset(mixed, plain))
        self.assertEqual([block.show_mod for block in blocks], [True, False])

    def test_the_aircraft_name_comes_from_the_specs(self) -> None:
        self.assertEqual(get_aircraft_name("A-10C_2"), "A-10C II")
        self.assertIsNone(get_aircraft_name("UNKNOWN-TYPE"))


class TestRows(unittest.TestCase):
    def test_rows_stop_at_the_last_channel_and_keep_the_gaps(self) -> None:
        rows = _kneeboard_rows(_radio("r", Channel(1, 251.0), Channel(3, 253.0)))
        self.assertEqual([row.label for row in rows], ["01", "02", "03"])
        self.assertIsNone(rows[1].channel)

    def test_a_labelled_radio_shows_its_labelled_slots(self) -> None:
        radio = _radio("r", Channel(1, 251.0))
        radio.display_labels = {1: "M", 2: "01", 3: "02"}
        self.assertEqual([row.label for row in _kneeboard_rows(radio)], ["M", "01", "02"])

    def test_frequencies_keep_a_third_decimal_only_when_set(self) -> None:
        self.assertEqual(_format_freq(121.5), "121.50")
        self.assertEqual(_format_freq(127.525), "127.525")
        self.assertEqual(_format_freq(30.0), "30.00")


class TestPagination(unittest.TestCase):
    def test_the_a10c2_fits_on_one_page(self) -> None:
        pages = _paginate_blocks([_block(9), _block(20), _block(30)])
        self.assertEqual(len(pages), 1)
        self.assertEqual([len(column) for column in pages[0]], [2, 1])

    def test_a_block_moves_whole_to_a_column_where_it_fits(self) -> None:
        # The first column keeps room for about 9 rows — more than the foot-of-column minimum, fewer than 15.
        full_column = (_COLUMN_H - _BLOCK_HEAD_H) // _ROW_H
        pages = _paginate_blocks([_block(full_column - 12), _block(15)])
        second = pages[0][1]
        self.assertEqual(len(pages[0][0]), 1)
        self.assertEqual(len(second), 1)
        self.assertFalse(second[0].continued)
        self.assertEqual(len(second[0].rows), 15)

    def test_a_block_taller_than_a_column_is_split_and_marked_continued(self) -> None:
        full_column = (_COLUMN_H - _BLOCK_HEAD_H) // _ROW_H
        pages = _paginate_blocks([_block(full_column + 12)])
        first, second = pages[0]
        self.assertEqual(len(first[0].rows), full_column)
        self.assertTrue(second[0].continued)
        self.assertEqual(len(second[0].rows), 12)

    def test_a_block_never_starts_with_few_rows_at_the_foot_of_a_column(self) -> None:
        # Leave room for 2 rows at the foot of the first column, then add a block too tall for any column.
        full_column = (_COLUMN_H - _BLOCK_HEAD_H) // _ROW_H
        used_rows = (_COLUMN_H - 2 * _BLOCK_HEAD_H - _BLOCK_GAP) // _ROW_H - 2
        pages = _paginate_blocks([_block(used_rows), _block(full_column + 5)])
        self.assertEqual(len(pages[0][0]), 1)

    def test_what_overflows_two_columns_goes_to_a_second_page(self) -> None:
        full_column = (_COLUMN_H - _BLOCK_HEAD_H) // _ROW_H
        pages = _paginate_blocks([_block(full_column), _block(full_column), _block(3)])
        self.assertEqual(len(pages), 2)
        self.assertEqual(len(pages[1][0][0].rows), 3)

    def test_nothing_gives_one_empty_page(self) -> None:
        self.assertEqual(_paginate_blocks([]), [[[], []]])


class TestPagePaths(unittest.TestCase):
    def _tall_preset(self) -> PresetDefinition:
        full_column = (_COLUMN_H - _BLOCK_HEAD_H) // _ROW_H
        return _preset(_filled("r1", full_column), _filled("r2", full_column), _filled("r3", 3, base=30.0))

    def test_an_overflowing_preset_continues_on_a_second_page(self) -> None:
        paths = set(
            RadioPresetsImageGenerator({}).generate_type_images({("blue", "UNKNOWN-TYPE"): self._tall_preset()})
        )
        self.assertEqual(
            paths, {"KNEEBOARD/UNKNOWN-TYPE/IMAGES/presets.png", "KNEEBOARD/UNKNOWN-TYPE/IMAGES/presets_2.png"}
        )

    def test_the_second_page_keeps_the_coalition_suffix(self) -> None:
        injected = {("blue", "UNKNOWN-TYPE"): self._tall_preset(), ("red", "UNKNOWN-TYPE"): _preset(_filled("r", 2))}
        paths = set(RadioPresetsImageGenerator({}).generate_type_images(injected))
        self.assertIn("KNEEBOARD/UNKNOWN-TYPE/IMAGES/presets-blue_2.png", paths)
        self.assertIn("KNEEBOARD/UNKNOWN-TYPE/IMAGES/presets-red.png", paths)

    def test_the_second_page_sorts_after_the_first(self) -> None:
        self.assertLess("presets.png", "presets_2.png")
        self.assertLess("presets-blue.png", "presets-blue_2.png")


class TestCalibrationPage(unittest.TestCase):
    """The calibration page ships with the presets pages, once, and only with them."""

    def _manager_images(self, injected: dict) -> dict:
        manager = PresetsManager()
        manager.generate_type_images(injected)
        return manager.presets_images or {}

    def test_it_comes_once_with_the_presets_pages(self) -> None:
        images = self._manager_images(
            {("blue", "UH-1H"): _preset(_filled("r", 2)), ("red", "UH-1H"): _preset(_filled("r", 2))}
        )
        self.assertEqual([path for path in images if "calibration" in path], [KNEEBOARD_CALIBRATION_PATH])

    def test_the_presets_pages_carry_no_target(self) -> None:
        # David, 2026-10-18: the calibration page alone, nothing on the presets pages themselves.
        with mock.patch.object(ImageDraw.ImageDraw, "ellipse") as ellipse:
            RadioPresetsImageGenerator({}).generate_type_images({("blue", "UH-1H"): _preset(_filled("r", 2))})
        ellipse.assert_not_called()

    def test_it_lives_in_the_folder_every_aircraft_shows(self) -> None:
        self.assertTrue(KNEEBOARD_CALIBRATION_PATH.startswith("KNEEBOARD/IMAGES/"))

    def test_no_presets_page_means_no_calibration_page(self) -> None:
        self.assertEqual(self._manager_images({("blue", "UH-1H"): _preset(_radio("empty"))}), {})


class TestPageTexts(unittest.TestCase):
    """The page's words follow the tool's language."""

    def tearDown(self) -> None:
        set_language("en")

    def _drawn(self, render) -> list[str]:
        drawn: list[str] = []
        real_text = ImageDraw.ImageDraw.text

        def spy(self, xy, text, *args, **kwargs):
            drawn.append(text)
            return real_text(self, xy, text, *args, **kwargs)

        with mock.patch.object(ImageDraw.ImageDraw, "text", spy):
            render()
        return drawn

    def _presets_page(self) -> None:
        RadioPresetsImageGenerator({}).generate_type_images({("blue", "A-10C_2"): _preset(_filled("r", 2))})

    def test_french_headers(self) -> None:
        set_language("fr")
        drawn = self._drawn(self._presets_page)
        self.assertIn("NOM", drawn)
        self.assertIn("Presets radio", drawn)
        self.assertIn("A-10C II", drawn)

    def test_english_headers(self) -> None:
        set_language("en")
        drawn = self._drawn(self._presets_page)
        self.assertIn("NAME", drawn)
        self.assertIn("Radio presets", drawn)

    def test_the_calibration_page_tells_what_to_do(self) -> None:
        set_language("fr")
        drawn = self._drawn(render_calibration_page)
        self.assertIn("Redimensionnez la fenêtre de la planchette", drawn)

    def test_the_priority_legend_shows_only_when_a_channel_has_one(self) -> None:
        set_language("en")
        legend = "Highlighted = priority (Pn)"
        plain = self._drawn(self._presets_page)
        with_priority = self._drawn(
            lambda: RadioPresetsImageGenerator({}).generate_type_images(
                {("blue", "UH-1H"): _preset(_radio("r", Channel(1, 251.0, title="A", priority=1)))}
            )
        )
        self.assertNotIn(legend, plain)
        self.assertIn(legend, with_priority)


if __name__ == "__main__":
    unittest.main()
