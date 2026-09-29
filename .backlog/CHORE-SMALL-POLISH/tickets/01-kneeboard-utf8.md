# 01 — radio kneeboards mangle non-ASCII names

Status: ✅ done

David, 2026-09-29: the radio kneeboards do not handle UTF-8 well; example *Nörvenich* on
Germany-v6.

## Measured before starting (2026-09-29)

- Our own tables spell it **`Norvenich`**, without the umlaut
  (`veaf_libs/data/airdromes.yaml`, `airfield-frequencies.yaml`). So the `ö` reaches the kneeboard
  from somewhere else: the mission's own names, DCS's airbase name, or a preset label. **Where it
  comes from is the first thing to establish**, on Germany-v6's generated kneeboard.
- The kneeboards are drawn with Pillow in `presets_injector/presets_manager.py` (~line 1923):
  `arial.ttf`, falling back to `ImageFont.load_default()` when Arial cannot be loaded. The default
  bitmap font has no glyph for `ö`, so a machine without Arial would draw a box. The other
  candidate is a decode somewhere on the way (Latin-1 read as UTF-8, or the reverse), which
  would draw `Ã¶`.

## Done when

- The kneeboard of Germany-v6 shows `Nörvenich` correctly.
- A test draws a name with a non-ASCII letter through the real path and asserts the text that
  reaches the drawing call, so a decoding error is caught; the font fallback is covered too.

## Closed (2026-09-29)

- **Where the `ö` comes from: the mission's own `presets.yaml`** (`Base-Norvenich: title: Nörvenich`,
  bytes `C3 B6`), read by `PresetsManager.read_yaml` with no `encoding=`, so with the locale's code
  page — `cp1252` on David's machine — which gives `NÃ¶rvenich`. Neither DCS nor the font.
- **The decoding fix is not in this lot.** Another session was writing it at the same time on
  `fix/presets-yaml-utf8` (every text `open()` of veaf-tools, with a test that fails on one opened
  without `encoding=`). David chose to leave it there rather than ship it twice.
- **The font hypothesis was wrong, measured:** with Pillow 12.3, `ImageFont.load_default()` is a
  FreeType font (FreeType is in the wheels) and draws the `ö`. Its real defect was the size: the
  three kneeboard fonts all fell back to 10 px instead of 18/30/40. Fixed with `load_default(size)`.
- Tests (`test_kneeboard_non_ascii.py`): a non-ASCII channel title reaches Pillow's `text()` call
  unchanged; without Arial, the fallback keeps the three sizes and draws the umlaut.
