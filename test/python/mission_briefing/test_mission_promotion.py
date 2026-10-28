"""A mission's poster, calendar banner and Discord post (FEAT-OBJECTIVE-MISSION-V2 12)."""

from __future__ import annotations

import io
import json
import shutil
from pathlib import Path

import pytest
from mission_briefing.mission_briefing_worker import build_mission_briefing
from mission_briefing.mission_promotion import (
    BANNER_SIZE,
    DISCORD_LIMIT,
    POSTER_SIZE,
    PromotionContent,
    build_mission_promotion,
)
from mission_briefing.models import BriefingContent, Objective
from objective_mission_fixture import objective_mission
from offline import offline
from PIL import Image
from veaf_mission_mcp.build_promotion import build_promotion

CONTENT = PromotionContent(
    title="Marteau de Khobi",
    event="jeudi 29 octobre · 21 h",
    tagline=("Percer le front.", "Briser la réserve."),
    pitch=("Le dépôt de Khobi ravitaille le front.",),
    program=("🐗 CAS : le dépôt et sa défense.",),
    practical=("6 à 12 pilotes, environ 2 h de vol",),
    calendar_url="https://www.veaf.org/calendar/1423",
    briefing_url="https://docs.google.com/presentation/d/x",
    closing="On vous attend !",
)


def _white(url: str) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (256, 256), (255, 255, 255)).save(buffer, format="PNG")
    return buffer.getvalue()


def _briefed(folder: Path) -> Path:
    objective_mission(folder)
    content = BriefingContent(title="Marteau de Khobi", objectives=(Objective("Khobi", "Le dépôt"),))
    build_mission_briefing(folder, content, cache_dir=folder / "tiles", fetch=_white)
    return folder


@pytest.fixture(scope="module")
def briefed_once(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """One briefing for the module, since a build takes seconds; never promoted itself."""
    folder = tmp_path_factory.mktemp("briefed")
    with offline(folder):
        return _briefed(folder)


@pytest.fixture
def briefed(briefed_once: Path, tmp_path: Path) -> Path:
    """A copy of the briefed folder: promoting writes into it, and a test may add recon photos."""
    folder = tmp_path / "m"
    shutil.copytree(briefed_once, folder, ignore=shutil.ignore_patterns("tiles"))
    return folder


def test_the_poster_and_the_banner_at_their_sizes(briefed: Path) -> None:
    report = build_mission_promotion(briefed, CONTENT)
    assert Image.open(report.poster).size == POSTER_SIZE
    width, height = Image.open(report.banner).size
    assert (width, height) == BANNER_SIZE
    assert width / height == pytest.approx(5.55, abs=0.01)  # what the VEAF calendar shows uncropped


def test_the_post_carries_the_words_the_mission_and_the_links(briefed: Path) -> None:
    report = build_mission_promotion(briefed, CONTENT)
    post = report.discord.read_text(encoding="utf-8")
    assert post.startswith("# Marteau de Khobi — jeudi 29 octobre · 21 h\n")
    assert "Le dépôt de Khobi ravitaille le front." in post
    assert "**Au programme**\n🐗 CAS : le dépôt et sa défense." in post
    assert "• Caucasus, " in post  # the theatre, read from the built mission
    assert "• 6 à 12 pilotes, environ 2 h de vol" in post
    assert "📅 **Inscription** : https://www.veaf.org/calendar/1423" in post
    assert "📋 **Briefing** : https://docs.google.com/presentation/d/x" in post
    assert report.discord_chars == len(post) < DISCORD_LIMIT
    assert report.warnings == ["No recon photo: the poster and the banner stand on the map alone."]


def test_no_event_no_date_anywhere_and_said(briefed: Path) -> None:
    content = PromotionContent(title="Marteau de Khobi")
    report = build_mission_promotion(briefed, content)
    post = report.discord.read_text(encoding="utf-8")
    assert post.startswith("# Marteau de Khobi\n")
    assert "Inscription" not in post and "Briefing" not in post
    joined = "\n".join(report.warnings)
    assert "never invent" in joined and "calendar_url" in joined and "briefing_url" in joined


def test_a_post_longer_than_discord_takes_is_refused(briefed: Path) -> None:
    content = PromotionContent(title="T", pitch=("x" * 2100,))
    with pytest.raises(ValueError, match="2000"):
        build_mission_promotion(briefed, content)


def test_without_the_briefing_s_maps_it_says_so(tmp_path: Path) -> None:
    objective_mission(tmp_path)
    report = build_mission_promotion(tmp_path, CONTENT)
    assert report.poster.is_file()
    assert any("build_mission_briefing" in warning for warning in report.warnings)


def test_a_recon_photo_is_pinned(briefed: Path) -> None:
    folder = briefed
    recon = folder / "docs" / "recon"
    recon.mkdir(parents=True)
    Image.new("RGB", (1600, 900), (90, 110, 70)).save(recon / "a.jpg")
    (recon / "a.json").write_text(json.dumps({"zone": "Khobi", "title": "Le dépôt"}), encoding="utf-8")
    report = build_mission_promotion(folder, CONTENT)
    assert not any("recon" in warning for warning in report.warnings)


def test_an_unbuilt_mission_is_refused(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="build_mission"):
        build_mission_promotion(tmp_path, CONTENT)


def test_the_action_hands_the_post_back(briefed: Path) -> None:
    folder = briefed
    result = build_promotion(
        {"mission_path": str(folder), "title": "Marteau de Khobi", "tagline": ["Percer le front."]}
    )
    assert result["discord_post"].startswith("# Marteau de Khobi")
    assert result["discord_chars"] == len(result["discord_post"])
    assert Path(result["poster"]).is_file() and Path(result["banner"]).is_file()
