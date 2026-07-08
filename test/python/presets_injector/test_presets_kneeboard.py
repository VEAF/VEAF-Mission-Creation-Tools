"""Kneeboard rendering tests (ADR 0012): priority highlight, colour, grey headers.

The rendering assertions inspect the rendered image for the presence/absence of
specific solid fill colours (highlight orange, a channel colour, the grey header),
which is robust to the exact table geometry.
"""

import unittest
from unittest.mock import patch

from presets_injector.presets_manager import (
    _PRIORITY_HIGHLIGHT,
    _RADIO_TITLE_BG,
    Channel,
    PresetDefinition,
    RadioDefinition,
    RadioPresetsImageGenerator,
    _contrast_text_color,
    _resolve_kneeboard_color,
)


def _preset(*channels: Channel) -> PresetDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf", title="UHF")
    for channel in channels:
        radio.add_channel(channel)
    preset = PresetDefinition(name="p", title="Test")
    preset.add_radio(radio)
    return preset


def _rendered_colors(preset: PresetDefinition) -> set[tuple[int, int, int]]:
    generator = RadioPresetsImageGenerator(preset_collections={})
    generator.radio_count = len(preset.radios)
    generator.draw_preset_image(preset)
    generator.draw_radios_in_preset_image(preset)
    return set(generator.image.getdata())


class TestColorHelpers(unittest.TestCase):
    def test_contrast_text_color(self):
        self.assertEqual(_contrast_text_color((0, 0, 128)), "white")  # dark navy
        self.assertEqual(_contrast_text_color((255, 255, 255)), "black")  # white

    def test_resolve_named_and_hex_colors(self):
        self.assertEqual(_resolve_kneeboard_color("green"), (0, 128, 0))
        self.assertEqual(_resolve_kneeboard_color("#000080"), (0, 0, 128))
        self.assertEqual(_resolve_kneeboard_color("#00008080"), (0, 0, 128))  # RGBA → RGB triple

    @patch("presets_injector.presets_manager.logger")
    def test_unknown_color_warns_and_returns_none(self, mock_logger):
        self.assertIsNone(_resolve_kneeboard_color("notacolor"))
        mock_logger.warning.assert_called_once()


class TestKneeboardRendering(unittest.TestCase):
    def test_priority_channel_highlights_in_orange(self):
        colors = _rendered_colors(_preset(Channel(1, 251.0, title="Alpha", priority=3)))
        self.assertIn(_PRIORITY_HIGHLIGHT, colors)

    def test_no_priority_means_no_orange_highlight(self):
        colors = _rendered_colors(_preset(Channel(1, 251.0, title="Alpha")))
        self.assertNotIn(_PRIORITY_HIGHLIGHT, colors)

    def test_color_fills_the_ch_cell(self):
        colors = _rendered_colors(_preset(Channel(1, 251.0, title="Alpha", color="#000080")))
        self.assertIn((0, 0, 128), colors)

    def test_named_color_fills_the_ch_cell(self):
        colors = _rendered_colors(_preset(Channel(1, 251.0, title="Alpha", color="green")))
        self.assertIn((0, 128, 0), colors)

    def test_radio_headers_are_grey_not_red_or_orange(self):
        colors = _rendered_colors(_preset(Channel(1, 251.0, title="Alpha")))
        self.assertIn(_RADIO_TITLE_BG, colors)  # grey header present
        self.assertNotIn((255, 0, 0), colors)  # old red coding gone
        self.assertNotIn((255, 165, 0), colors)  # old orange coding gone


if __name__ == "__main__":
    unittest.main()
