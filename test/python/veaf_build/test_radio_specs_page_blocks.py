"""The radio-specs generator must edit blocks, never whole pages.

`update-dcs-data --radio` used to name a single Markdown output — `dcs-radio-specs.md`, the
**French** page, the site's default locale — and write the whole page to it, in English, while never
opening the English one. Running it replaced 100 lines of hand-written French prose with 84 of
generated English, and `docs-check` stayed green throughout: a French page full of English text is
not a defect the gate can express.

`dcs-data-drift.yml` told whoever ran the command to restore the prose by hand across both pages, so
nobody was unaware. What was missing is anything that catches the omission — which is what these
tests are.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from veaf_build.radio_specs_updater import (
    OUTPUT_PAGES,
    AircraftRadio,
    AircraftSpec,
    FrequencyRange,
    HumanRadio,
    MissingBlockError,
    build_source_block,
    build_tables_block,
    replace_block,
    write_markdown,
)

#: Every block the generator writes, so a page missing one fails loudly rather than silently.
BLOCK_NAMES = ("source note", "aircraft tables", "primary frequency")


def _specs() -> list[AircraftSpec]:
    return [
        AircraftSpec(
            dcs_id="FW-190A8",
            display_name="Fw 190 A-8",
            category="plane",
            radios=[AircraftRadio(name="FuG 16", ranges=[FrequencyRange(38.0, 156.0, "AM")])],
            human_radio=HumanRadio(38.4, 42.4, 38.4, "AM"),
        ),
        AircraftSpec(
            dcs_id="UH-1H",
            display_name="UH-1H",
            category="helicopter",
            radios=[AircraftRadio(name="ARC-51", ranges=[FrequencyRange(225.0, 399.975, "AM")])],
        ),
    ]


def _page(tmp_path: Path, *, blocks: tuple[str, ...] = BLOCK_NAMES) -> Path:
    """A page with hand-written prose above and below each block."""
    lines = ["# Une page rédigée à la main", "", "Cette prose doit survivre à toute régénération.", ""]
    for name in blocks:
        lines += [
            f"<!-- BEGIN generated: {name} -->",
            "stale content the generator replaces",
            f"<!-- END generated: {name} -->",
            "",
            f"Prose française après le bloc {name}, avec un accent aigu.",
            "",
        ]
    page = tmp_path / "page.md"
    page.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return page


class TestProseSurvives:
    def test_regeneration_leaves_every_hand_written_line_intact(self, tmp_path: Path) -> None:
        page = _page(tmp_path)
        before = page.read_text(encoding="utf-8").splitlines()
        write_markdown(_specs(), {"fr": page})
        after = page.read_text(encoding="utf-8").splitlines()
        prose = [line for line in before if line.startswith(("#", "Cette prose", "Prose française"))]
        assert prose, "the fixture must contain prose, or this proves nothing"
        for line in prose:
            assert line in after, f"lost a hand-written line: {line!r}"

    def test_the_stale_block_content_is_gone(self, tmp_path: Path) -> None:
        page = _page(tmp_path)
        write_markdown(_specs(), {"fr": page})
        assert "stale content the generator replaces" not in page.read_text(encoding="utf-8")

    def test_both_languages_are_written(self, tmp_path: Path) -> None:
        # The English page was never opened at all — the other half of the defect.
        (tmp_path / "fr").mkdir()
        (tmp_path / "en").mkdir()
        fr, en = _page(tmp_path / "fr"), _page(tmp_path / "en")
        write_markdown(_specs(), {"fr": fr, "en": en})
        assert "## Avions" in fr.read_text(encoding="utf-8")
        assert "## Fixed-wing aircraft" in en.read_text(encoding="utf-8")
        assert "## Avions" not in en.read_text(encoding="utf-8"), "the English page must not carry French headings"


class TestMissingMarkers:
    def test_a_page_without_a_block_fails_loudly(self, tmp_path: Path) -> None:
        # A generator that quietly does nothing is how a stale table ships; overwriting the page
        # whole is the defect this lot removes. Neither is acceptable, so it raises.
        page = _page(tmp_path, blocks=("source note", "aircraft tables"))
        with pytest.raises(MissingBlockError, match="primary frequency"):
            write_markdown(_specs(), {"fr": page})

    def test_a_half_marked_block_fails_too(self, tmp_path: Path) -> None:
        page = _page(tmp_path)
        text = page.read_text(encoding="utf-8").replace("<!-- END generated: aircraft tables -->", "")
        page.write_text(text, encoding="utf-8", newline="\n")
        with pytest.raises(MissingBlockError, match="aircraft tables"):
            write_markdown(_specs(), {"fr": page})

    def test_a_duplicated_marker_fails_rather_than_picking_one(self, tmp_path: Path) -> None:
        page = _page(tmp_path)
        text = page.read_text(encoding="utf-8")
        page.write_text(text + "\n<!-- BEGIN generated: source note -->\n", encoding="utf-8", newline="\n")
        with pytest.raises(MissingBlockError, match="source note"):
            write_markdown(_specs(), {"fr": page})


class TestLocalisation:
    @pytest.mark.parametrize(
        ("language", "expected", "unexpected"),
        [
            ("fr", "## Hélicoptères", "## Helicopters"),
            ("en", "## Helicopters", "## Hélicoptères"),
        ],
    )
    def test_category_headings_follow_the_page(self, language: str, expected: str, unexpected: str) -> None:
        block = "\n".join(build_tables_block(_specs(), language))
        assert expected in block
        assert unexpected not in block

    def test_column_headers_follow_the_page(self) -> None:
        assert "| Appareil | ID DCS |" in "\n".join(build_tables_block(_specs(), "fr"))
        assert "| Aircraft | DCS ID |" in "\n".join(build_tables_block(_specs(), "en"))

    def test_the_source_note_carries_the_pinned_ref(self) -> None:
        # Generated rather than hand-written precisely because this value changes on every bump.
        from veaf_build.dcs_data.datamine import DATAMINE_REF

        for language in ("fr", "en"):
            assert DATAMINE_REF in "\n".join(build_source_block(language))


class TestShippedPages:
    @pytest.mark.parametrize("language", ["fr", "en"])
    def test_the_shipped_page_carries_every_block(self, language: str) -> None:
        # Without this, adding a block to the generator would break the next regeneration rather
        # than this test — and the person hitting it would be mid-release.
        text = OUTPUT_PAGES[language].read_text(encoding="utf-8")
        for name in BLOCK_NAMES:
            assert text.count(f"<!-- BEGIN generated: {name} -->") == 1, f"{language}: {name}"
            assert text.count(f"<!-- END generated: {name} -->") == 1, f"{language}: {name}"

    def test_the_two_pages_point_at_different_files(self) -> None:
        # The whole defect in one assertion: there used to be a single output, and it was the French
        # page.
        assert OUTPUT_PAGES["fr"] != OUTPUT_PAGES["en"]
        assert OUTPUT_PAGES["en"].name.endswith(".en.md")


def test_replace_block_touches_nothing_outside_the_markers(tmp_path: Path) -> None:
    page = tmp_path / "p.md"
    page.write_text(
        "avant\n<!-- BEGIN generated: x -->\nvieux\n<!-- END generated: x -->\naprès\n",
        encoding="utf-8",
        newline="\n",
    )
    replace_block(page, "x", ["neuf"])
    assert page.read_text(encoding="utf-8") == (
        "avant\n<!-- BEGIN generated: x -->\nneuf\n<!-- END generated: x -->\naprès\n"
    )
