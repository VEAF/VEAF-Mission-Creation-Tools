"""ERA-AUTODETECT-001 — mission-era detection helper."""

from __future__ import annotations

from mission_builder.era_detector import ERA_COLD_WAR, ERA_MODERN, ERA_WW2, detect_era


def _mission(year: int | None = None, unit_type: str | None = None) -> dict:
    content: dict = {}
    if year is not None:
        content["date"] = {"Day": 1, "Month": 6, "Year": year}
    if unit_type is not None:
        content["coalition"] = {
            "blue": {"country": [{"name": "USA", "plane": {"group": [{"units": [{"type": unit_type}]}]}}]}
        }
    return content


class TestDetectEra:
    def test_ww2_by_year(self) -> None:
        assert detect_era(_mission(year=1944)) == ERA_WW2

    def test_ww2_boundary_year_1945(self) -> None:
        assert detect_era(_mission(year=1945)) == ERA_WW2

    def test_ww2_by_unit_type_overrides_modern_year(self) -> None:
        # A WW2 aircraft present even with a modern default year → WW2.
        assert detect_era(_mission(year=2011, unit_type="SpitfireLFMkIX")) == ERA_WW2

    def test_ww2_by_ground_unit(self) -> None:
        assert detect_era(_mission(year=2000, unit_type="Tiger_II")) == ERA_WW2

    def test_cold_war_year(self) -> None:
        assert detect_era(_mission(year=1975)) == ERA_COLD_WAR

    def test_cold_war_boundary_1991(self) -> None:
        assert detect_era(_mission(year=1991)) == ERA_COLD_WAR

    def test_modern_year(self) -> None:
        assert detect_era(_mission(year=2011)) == ERA_MODERN

    def test_modern_boundary_1992(self) -> None:
        assert detect_era(_mission(year=1992)) == ERA_MODERN

    def test_modern_aircraft_does_not_trigger_ww2(self) -> None:
        assert detect_era(_mission(year=2011, unit_type="F-16C_50")) == ERA_MODERN

    def test_default_modern_when_no_year_no_units(self) -> None:
        assert detect_era({}) == ERA_MODERN

    def test_dict_shaped_tables_supported(self) -> None:
        # DCS 1-based tables sometimes decode to dicts — must still scan.
        content = {
            "date": {"Year": 2011},
            "coalition": {
                "blue": {"country": {1: {"plane": {"group": {1: {"units": {1: {"type": "P-51D"}}}}}}}}
            },
        }
        assert detect_era(content) == ERA_WW2

    def test_malformed_content_does_not_crash(self) -> None:
        assert detect_era({"coalition": "nonsense", "date": "bad"}) == ERA_MODERN

    def test_non_integer_year_defaults_to_modern(self) -> None:
        # Locks in the isinstance(..., int) guard: a string/None year is ignored.
        assert detect_era({"date": {"Year": "2011"}}) == ERA_MODERN
        assert detect_era({"date": {"Year": None}}) == ERA_MODERN
