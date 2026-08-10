"""SECREV-2 / VMR-051 — an explicit null coordinate defeated the key fallback.

`convert_weather` resolved a position with `pos.get("lat", pos.get("latitude"))`. `dict.get` only
reaches its default when the key is **absent**, so a v5 JSON carrying `"lat": null` alongside a
real `latitude` returned None and the coordinate was silently dropped from the v6 YAML — the
mission ends up positioned nowhere, with no warning.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

import yaml
from mission_builder.v5_pipeline_converters import convert_weather


def _convert(v5: dict[str, Any]) -> dict[str, Any]:
    folder = Path(tempfile.mkdtemp())
    v5_path = folder / "versions.json"
    v6_path = folder / "versions.yaml"
    v5_path.write_text(json.dumps(v5), encoding="utf-8")
    convert_weather(v5_path, v6_path)
    return yaml.safe_load(v6_path.read_text(encoding="utf-8")) or {}


class TestPositionKeyFallback(unittest.TestCase):
    def test_v5_short_keys_are_renamed(self) -> None:
        # The baseline: this is the shape the converter was written for.
        out = _convert({"position": {"lat": 41.5, "lon": 42.5, "tz": 4}})
        self.assertEqual(out["position"], {"latitude": 41.5, "longitude": 42.5, "timezone": 4})

    def test_long_keys_alone_are_kept(self) -> None:
        out = _convert({"position": {"latitude": 41.5, "longitude": 42.5, "timezone": 4}})
        self.assertEqual(out["position"], {"latitude": 41.5, "longitude": 42.5, "timezone": 4})

    def test_an_explicit_null_short_key_falls_back_to_the_long_one(self) -> None:
        out = _convert(
            {"position": {"lat": None, "lon": None, "tz": None, "latitude": 41.5, "longitude": 42.5, "timezone": 4}}
        )
        self.assertEqual(
            out["position"],
            {"latitude": 41.5, "longitude": 42.5, "timezone": 4},
            "an explicit null dropped the coordinate instead of falling back",
        )

    def test_a_mixed_source_keeps_both_coordinates(self) -> None:
        out = _convert({"position": {"lat": 41.5, "lon": None, "longitude": 42.5}})
        self.assertEqual(out["position"]["latitude"], 41.5)
        self.assertEqual(out["position"]["longitude"], 42.5)

    def test_a_genuinely_absent_coordinate_stays_none(self) -> None:
        # The control: the fallback must not invent a value where the source has none.
        out = _convert({"position": {"lat": 41.5}})
        self.assertEqual(out["position"]["latitude"], 41.5)
        self.assertIsNone(out["position"]["longitude"])


if __name__ == "__main__":
    unittest.main()
