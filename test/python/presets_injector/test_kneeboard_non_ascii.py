"""Kneeboard pages keep non-ASCII channel names (CHORE-SMALL-POLISH, ticket 01).

"Nörvenich" came out garbled on the GermanyCW kneeboards (2026-09-29). The garbling happened when
`presets.yaml` was read, not when the page was drawn; these tests pin the drawing half: the name
reaches Pillow's `text()` call unchanged, and the font used when Arial cannot be loaded draws the
umlaut at the sizes the page is laid out for.
"""

import unittest
from unittest import mock

from PIL import Image, ImageDraw, ImageFont
from presets_injector.presets_manager import (
    Channel,
    PresetDefinition,
    RadioDefinition,
    RadioPresetsImageGenerator,
)


def _preset_with(title: str) -> PresetDefinition:
    radio = RadioDefinition(name="r", radio_type="uhf", title="UHF")
    radio.add_channel(Channel(1, 270.4, title))
    preset = PresetDefinition(name="p", title="t")
    preset.add_radio(radio)
    return preset


def _render(text: str, font: ImageFont.FreeTypeFont) -> bytes:
    image = Image.new("L", (200, 60))
    ImageDraw.Draw(image).text((0, 0), text, font=font, fill=255)
    return image.tobytes()


class TestNonAsciiNameReachesTheDrawing(unittest.TestCase):
    def test_the_channel_title_is_drawn_unchanged(self) -> None:
        drawn: list[str] = []
        real_text = ImageDraw.ImageDraw.text

        def spy(self, xy, text, *args, **kwargs):
            drawn.append(text)
            return real_text(self, xy, text, *args, **kwargs)

        with mock.patch.object(ImageDraw.ImageDraw, "text", spy):
            RadioPresetsImageGenerator(preset_collections={}).generate_type_images(
                {("blue", "A-10C"): _preset_with("Nörvenich")}
            )

        self.assertIn("Nörvenich", drawn)


class TestFallbackFont(unittest.TestCase):
    """Without Arial (a machine without the Windows fonts), the page falls back to Pillow's own font."""

    def _fallback_fonts(self) -> tuple[ImageFont.FreeTypeFont, ...]:
        real_truetype = ImageFont.truetype

        def no_arial(font, *args, **kwargs):
            # load_default() goes through truetype() too, with its embedded font: refuse only Arial.
            if font == "arial.ttf":
                raise OSError("cannot open resource")
            return real_truetype(font, *args, **kwargs)

        with mock.patch.object(ImageFont, "truetype", no_arial):
            return RadioPresetsImageGenerator(preset_collections={}).get_fonts()

    def test_the_fallback_keeps_the_layout_sizes(self) -> None:
        self.assertEqual([font.size for font in self._fallback_fonts()], [18, 30, 40])

    def test_the_fallback_draws_the_umlaut(self) -> None:
        for font in self._fallback_fonts():
            with self.subTest(size=font.size):
                self.assertNotEqual(_render("Nörvenich", font), _render("Norvenich", font))


if __name__ == "__main__":
    unittest.main()
