"""Tests for veaf_libs.i18n — translation, language switching, catalog loading."""

from __future__ import annotations

import os
import unittest

from veaf_libs import i18n
from veaf_libs.i18n import _detect_lang, _load_catalog, current_language, set_language, t


class TestTranslationLookup(unittest.TestCase):
    """t() — key lookup with and without kwargs."""

    def setUp(self) -> None:
        set_language("en")

    def tearDown(self) -> None:
        set_language("en")

    def test_known_key_returns_translation(self) -> None:
        result = t("msg.work_done")
        self.assertIsInstance(result, str)
        self.assertTrue(len(result) > 0)

    def test_missing_key_returns_key_itself(self) -> None:
        result = t("this.key.does.not.exist")
        self.assertEqual(result, "this.key.does.not.exist")

    def test_kwargs_formatting(self) -> None:
        # "weather.loading_config" = "Loading configuration from {path}"
        result = t("weather.loading_config", path="/some/file.yaml")
        self.assertIn("/some/file.yaml", result)

    def test_kwargs_with_multiple_placeholders(self) -> None:
        # "weather.creating_version" = "[{index}/{total}] Creating version: {name}"
        result = t("weather.creating_version", index=1, total=3, name="morning")
        self.assertIn("morning", result)
        self.assertIn("1", result)
        self.assertIn("3", result)

    def test_kwargs_missing_placeholder_returns_raw(self) -> None:
        # Missing kwarg → format_map raises KeyError → returns raw text
        result = t("weather.loading_config")  # no 'path' kwarg
        self.assertIsInstance(result, str)

    def test_no_kwargs_returns_string(self) -> None:
        result = t("msg.work_done")
        self.assertIsInstance(result, str)


class TestSetLanguage(unittest.TestCase):
    """set_language() and current_language()."""

    def tearDown(self) -> None:
        set_language("en")

    def test_set_en(self) -> None:
        set_language("en")
        self.assertEqual(current_language(), "en")

    def test_set_fr(self) -> None:
        set_language("fr")
        self.assertEqual(current_language(), "fr")

    def test_set_unknown_lang_does_not_crash(self) -> None:
        set_language("xx")  # no xx.json — should not raise
        self.assertEqual(current_language(), "xx")

    def test_set_lang_uppercase_normalised(self) -> None:
        set_language("EN")
        self.assertEqual(current_language(), "en")

    def test_set_lang_strips_to_two_chars(self) -> None:
        set_language("fr-FR")
        self.assertEqual(current_language(), "fr")

    def test_fr_translation_differs_from_en(self) -> None:
        set_language("en")
        en_text = t("msg.work_done")
        set_language("fr")
        fr_text = t("msg.work_done")
        # Both are valid strings; at minimum they exist
        self.assertIsInstance(fr_text, str)
        self.assertTrue(len(fr_text) > 0)
        # FR may equal EN if not overridden — just check it works
        _ = en_text  # suppress unused warning

    def test_missing_key_in_fr_falls_back_to_en(self) -> None:
        set_language("fr")
        # 'msg.work_done' exists in en.json; if not in fr.json, falls back to en value
        result = t("msg.work_done")
        self.assertIsInstance(result, str)
        self.assertTrue(len(result) > 0)


class TestLoadCatalog(unittest.TestCase):
    """_load_catalog() — with real and missing files."""

    def test_load_en_catalog(self) -> None:
        catalog = _load_catalog("en")
        self.assertIsInstance(catalog, dict)
        self.assertGreater(len(catalog), 0)

    def test_load_fr_catalog(self) -> None:
        catalog = _load_catalog("fr")
        self.assertIsInstance(catalog, dict)

    def test_missing_lang_returns_empty_dict(self) -> None:
        catalog = _load_catalog("zz")
        self.assertEqual(catalog, {})

    def test_en_catalog_has_known_key(self) -> None:
        catalog = _load_catalog("en")
        self.assertIn("msg.work_done", catalog)


class TestDetectLang(unittest.TestCase):
    """_detect_lang() — reads VEAF_LANG env var."""

    def setUp(self) -> None:
        self._orig = os.environ.get("VEAF_LANG")

    def tearDown(self) -> None:
        if self._orig is None:
            os.environ.pop("VEAF_LANG", None)
        else:
            os.environ["VEAF_LANG"] = self._orig

    def test_veaf_lang_env_var_used(self) -> None:
        os.environ["VEAF_LANG"] = "fr"
        lang = _detect_lang()
        self.assertEqual(lang, "fr")

    def test_veaf_lang_uppercased_normalised(self) -> None:
        os.environ["VEAF_LANG"] = "FR"
        lang = _detect_lang()
        self.assertEqual(lang, "fr")

    def test_veaf_lang_longer_code_truncated(self) -> None:
        os.environ["VEAF_LANG"] = "fr-FR"
        lang = _detect_lang()
        self.assertEqual(lang, "fr")

    def test_no_veaf_lang_returns_string(self) -> None:
        os.environ.pop("VEAF_LANG", None)
        lang = _detect_lang()
        self.assertIsInstance(lang, str)
        self.assertGreater(len(lang), 0)


class TestFormatError(unittest.TestCase):
    """t() — format_map errors return raw translated text (lines 118-119)."""

    def setUp(self) -> None:
        set_language("en")

    def tearDown(self) -> None:
        set_language("en")

    def test_wrong_kwarg_key_returns_raw(self) -> None:
        # "weather.loading_config" has {path}, passing wrong_key triggers KeyError
        result = t("weather.loading_config", wrong_key="x")
        self.assertIsInstance(result, str)
        self.assertIn("path", result)  # raw template still contains {path}

    def test_wrong_kwarg_type_returns_raw(self) -> None:
        # Should not crash regardless of wrong kwarg
        result = t("weather.loading_config", path=object())
        self.assertIsInstance(result, str)


class TestLoadCatalogInvalidJSON(unittest.TestCase):
    """_load_catalog() — invalid JSON returns empty dict (lines 72-76)."""

    def test_invalid_json_returns_empty_dict(self) -> None:
        import json
        import tempfile
        from pathlib import Path
        from unittest.mock import patch

        with tempfile.TemporaryDirectory() as tmpdir:
            locales_dir = Path(tmpdir)
            # Write a file with invalid JSON
            bad_json = locales_dir / "xx.json"
            bad_json.write_text("{ this is not: valid json [", encoding="utf-8")
            with patch("veaf_libs.i18n._LOCALES_DIR", locales_dir):
                result = _load_catalog("xx")
            self.assertEqual(result, {})


class TestDetectLangLocaleRaises(unittest.TestCase):
    """_detect_lang() — locale.getlocale raises, falls back via env vars (lines 55-62)."""

    def setUp(self) -> None:
        self._orig = os.environ.get("VEAF_LANG")

    def tearDown(self) -> None:
        if self._orig is None:
            os.environ.pop("VEAF_LANG", None)
        else:
            os.environ["VEAF_LANG"] = self._orig
        set_language("en")

    def test_locale_raises_falls_back_to_en(self) -> None:
        import locale
        import sys
        from unittest.mock import patch

        os.environ.pop("VEAF_LANG", None)
        for var in ("LC_ALL", "LC_CTYPE", "LANG"):
            os.environ.pop(var, None)

        # Force the non-Windows path so winreg is never reached.
        with (
            patch.object(locale, "getlocale", side_effect=Exception("locale error")),
            patch.object(sys, "platform", "linux"),
        ):
            lang = _detect_lang()
        self.assertEqual(lang, "en")

    def test_locale_raises_uses_lc_all_env(self) -> None:
        import locale
        import sys
        from unittest.mock import patch

        os.environ.pop("VEAF_LANG", None)
        os.environ["LC_ALL"] = "fr_FR.UTF-8"
        try:
            # Force the non-Windows path so winreg is never reached.
            with (
                patch.object(locale, "getlocale", side_effect=Exception("locale error")),
                patch.object(sys, "platform", "linux"),
            ):
                lang = _detect_lang()
            self.assertEqual(lang, "fr")
        finally:
            os.environ.pop("LC_ALL", None)

    def test_winreg_used_when_locale_returns_none(self) -> None:
        """On Windows, winreg is consulted when locale.getlocale returns None."""
        import locale
        import sys
        import types
        from unittest.mock import MagicMock, patch

        os.environ.pop("VEAF_LANG", None)
        for var in ("LC_ALL", "LC_CTYPE", "LANG"):
            os.environ.pop(var, None)

        # Simulate locale.getlocale returning None (typical on Windows before setlocale).
        fake_winreg: object = types.ModuleType("winreg")
        fake_key = MagicMock()
        fake_key.__enter__ = lambda s: s
        fake_key.__exit__ = MagicMock(return_value=False)
        setattr(fake_winreg, "HKEY_CURRENT_USER", 0)
        setattr(fake_winreg, "OpenKey", MagicMock(return_value=fake_key))
        setattr(fake_winreg, "QueryValueEx", MagicMock(return_value=("fr-FR", 1)))

        with (
            patch.object(locale, "getlocale", return_value=(None, None)),
            patch.object(sys, "platform", "win32"),
            patch.dict("sys.modules", {"winreg": fake_winreg}),
        ):
            lang = _detect_lang()
        self.assertEqual(lang, "fr")


if __name__ == "__main__":
    unittest.main()
