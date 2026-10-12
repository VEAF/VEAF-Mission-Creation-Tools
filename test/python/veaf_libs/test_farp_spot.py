"""Tests for the in-game finder of a flat, clear FARP spot (FIX-FARP-PLACEMENT ticket 03).

DCS is never reached here: the transport is a fake that answers in the format the Lua chunk writes, so
what is tested is the chunks sent — one per band, in DCS axes, with the criteria — and the parsing of
their answers. Whether the criteria find a usable spot is the Marianas measurement of 2026-10-12: one
spot within 1.2 km of Merizo, 2.5 m of height range over 80 m, where the FARP was moved.
"""

import re

import pytest
from veaf_libs.farp_spot import FarpSpotError, band_chunk, find_farp_spots, parse_point


def _bands(code: list[str]) -> list[tuple[int, int]]:
    return [(int(m[1]), int(m[2])) for m in (re.search(r"dzmin, dzmax = (-?\d+), (-?\d+)", c) for c in code) if m]


class TestTheChunks:
    def test_the_grid_is_cut_into_bands_that_cover_it_once(self) -> None:
        sent: list[str] = []

        def exec_lua(code: str) -> str:
            sent.append(code)
            return ""

        find_farp_spots(exec_lua, 1000.0, 2000.0, radius=1200.0)
        bands = _bands(sent)
        assert bands[0][0] == -1200 and bands[-1][1] == 1200
        # Contiguous, one 50 m step apart, each at most 300 m wide: under the bridge's call timeout.
        assert all(nxt[0] == cur[1] + 50 for cur, nxt in zip(bands, bands[1:], strict=False))
        assert all(hi - lo < 300 for lo, hi in bands)

    def test_a_chunk_is_written_in_dcs_axes_with_the_criteria(self) -> None:
        """Mission ``y`` is DCS ``z``: a point sent the wrong way round searches 100 km away, silently."""
        code = band_chunk(-22300.0, -12450.0, radius=1200.0, max_drop=3.0, dz_min=-1200, dz_max=-950)
        assert "local cx, cz = -22300, -12450" in code
        assert "Disposition.getSimpleZones, p, 20, 5, 10" in code
        assert "land.getSurfaceType" in code and "land.getHeight" in code
        assert "local radius, step, ring, maxdrop = 1200, 50, 40, 3.0" in code


class TestTheAnswers:
    def test_spots_come_back_nearest_first_with_their_drop_and_distance(self) -> None:
        answers = iter(["1300\t2000\t2.5\n1050\t2000\t1.0", "", "1000\t2400\t0.5"])

        def exec_lua(_code: str) -> str:
            return next(answers, "")

        spots = find_farp_spots(exec_lua, 1000.0, 2000.0, radius=400.0)
        assert [(s.x, s.y, s.drop, s.distance) for s in spots] == [
            (1050.0, 2000.0, 1.0, 50.0),
            (1300.0, 2000.0, 2.5, 300.0),
            (1000.0, 2400.0, 0.5, 400.0),
        ]

    def test_a_band_that_raised_in_dcs_is_an_error_not_an_empty_answer(self) -> None:
        def exec_lua(_code: str) -> str:
            return "!\tattempt to index a nil value"

        with pytest.raises(FarpSpotError, match="attempt to index"):
            find_farp_spots(exec_lua, 0.0, 0.0, radius=100.0)

    def test_a_line_that_is_not_a_spot_is_refused(self) -> None:
        with pytest.raises(FarpSpotError, match="unexpected"):
            find_farp_spots(lambda _code: "hello", 0.0, 0.0, radius=100.0)

    def test_each_band_is_reported_as_it_completes(self) -> None:
        seen: list[tuple[int, int]] = []
        find_farp_spots(
            lambda _code: "", 0.0, 0.0, radius=450.0, on_band=lambda done, total: seen.append((done, total))
        )
        assert seen == [(1, 4), (2, 4), (3, 4), (4, 4)]


class TestThePoint:
    def test_a_negative_point_is_read(self) -> None:
        assert parse_point("-22300,-12450") == (-22300.0, -12450.0)

    @pytest.mark.parametrize("spec", ["1,2,3", "a,b", "12"])
    def test_anything_else_is_refused(self, spec: str) -> None:
        with pytest.raises(ValueError, match="x,y"):
            parse_point(spec)
