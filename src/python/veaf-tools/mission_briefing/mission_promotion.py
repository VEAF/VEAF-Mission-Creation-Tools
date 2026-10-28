"""A mission's poster, calendar banner and Discord post, from the built mission (FEAT-OBJECTIVE-MISSION-V2 12).

"Marteau du Golan" was announced with a 16:9 poster, a banner for the VEAF calendar and a Discord post,
all made by hand: a background from DCS, the combat-area map and a recon photo pinned on it, the title,
three lines of tagline. This makes the same three from what the mission folder holds — the built
mission (theatre, time of day, weather, departures), the briefing's maps (`build_mission_briefing`) and
its recon photos — around the words the assistant passes.

The evening's date and hour are the club's, not the mission's: they are a parameter, and never
invented. The calendar shows its banner at 5.55:1 and crops anything else at the centre: the banner is
drawn at exactly that ratio. Discord refuses a message over 2 000 characters: a post that long is
refused here, with its length, for the assistant to shorten.
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from pathlib import Path

from campaign_manager.mission_picture import MissionPicture, find_built_mission, read_mission_picture
from campaign_manager.strategic_map import _font
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps
from veaf_libs.bundled_data import bundled_dir
from veaf_libs.i18n import language, t
from veaf_libs.terrain_elevation import metres_to_feet

from mission_briefing.briefing_maps import COMBAT_AREA_FILE, OVERVIEW_FILE
from mission_briefing.briefing_recon import RECON_FOLDER, load_recon
from mission_briefing.mission_briefing_worker import MAPS_FOLDER, _mission_language
from mission_briefing.models import ReconPhoto

#: What this writes, in the mission folder.
POSTER_FILE = Path("docs") / "poster.jpg"
BANNER_FILE = Path("docs") / "calendar-banner.jpg"
DISCORD_FILE = Path("docs") / "discord-post.md"

#: The poster, 16:9.
POSTER_SIZE = (1920, 1080)

#: The VEAF calendar's banner: 5.55:1, the ratio it shows without cropping.
BANNER_SIZE = (2400, 432)

#: Discord's limit on a message, characters.
DISCORD_LIMIT = 2000

_GOLD = (235, 190, 110)
_PAPER = (245, 242, 232)
_RED = (200, 25, 25)


@dataclass(frozen=True)
class PromotionContent:
    """The words of the announcement: what the assistant passes, never a figure the mission holds."""

    title: str
    event: str = ""
    """The evening's local date and hour, as the club announces it (``jeudi 29 octobre, 21 h``); never invented."""
    tagline: tuple[str, ...] = ()
    """One to three short lines under the title."""
    pitch: tuple[str, ...] = ()
    """The post's opening paragraphs."""
    program: tuple[str, ...] = ()
    """The post's "on the menu" lines, one per role."""
    aircraft: tuple[str, ...] = ()
    """The types flown, for the poster's last line; the named flights' types when empty."""
    practical: tuple[str, ...] = ()
    """More practical lines (opposition level, number of pilots, duration…), after those the mission gives."""
    calendar_url: str = ""
    briefing_url: str = ""
    closing: str = ""
    """The post's last line."""


@dataclass(frozen=True)
class PromotionReport:
    """What was written."""

    poster: Path
    banner: Path
    discord: Path
    discord_chars: int
    warnings: list[str] = field(default_factory=list)


def _title_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """Impact when the system has it (the poster's look), the bundled DejaVu Sans Bold otherwise."""
    for candidate in ("impact.ttf", str(bundled_dir("veaf_libs", "data", "fonts") / "DejaVuSans-Bold.ttf")):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return _font(size, bold=True)


def _cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """The image scaled to cover ``size``, cut at the centre."""
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.convert("RGB").resize((round(image.width * scale) + 1, round(image.height * scale) + 1))
    left, top = (resized.width - size[0]) // 2, (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def _background(source: Image.Image | None, size: tuple[int, int], text_share: float) -> Image.Image:
    """An evening grade of the photo (or the map), darker where the text goes, on the left."""
    width, height = size
    if source is None:
        base = Image.new("RGB", size, (40, 46, 52))
    else:
        base = ImageEnhance.Contrast(_cover(source, size)).enhance(1.25)
        warm = ImageOps.colorize(ImageOps.grayscale(base), black=(10, 22, 34), mid=(120, 92, 60), white=(255, 214, 150))
        base = Image.blend(base, warm, 0.55)
    shade = Image.new("L", size)
    draw = ImageDraw.Draw(shade)
    for x in range(width):
        draw.line([(x, 0), (x, height)], fill=int(235 * max(0.0, 1 - x / (width * text_share)) ** 1.4))
    base = Image.composite(Image.new("RGB", size, (6, 8, 12)), base, shade)
    vignette = Image.radial_gradient("L").resize(size).point(lambda v: int(v * 0.8))
    base = Image.composite(Image.new("RGB", size, (0, 0, 0)), base, vignette)
    random.seed(3)
    return Image.blend(base, Image.effect_noise(size, 18).convert("RGB"), 0.05)


def _pinned(image: Image.Image, width: int, angle: float, caption: str = "") -> tuple[Image.Image, Image.Image]:
    """A print with a white border, its caption under it, turned; and its shadow."""
    picture = image.convert("RGB")
    picture = picture.resize((width, round(picture.height * width / picture.width)))
    border = max(8, width // 50)
    bottom = border * 4 if caption else border * 3
    framed = Image.new("RGB", (picture.width + 2 * border, picture.height + 2 * border + bottom), (238, 234, 222))
    framed.paste(picture, (border, border))
    if caption:
        ImageDraw.Draw(framed).text(
            (border + 6, picture.height + border + border // 2),
            caption,
            fill=_RED,
            font=_font(max(16, width // 22), bold=True),
        )
    turned = framed.convert("RGBA").rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    shadow = Image.new("RGBA", turned.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 150), mask=turned.split()[3])
    return turned, shadow.filter(ImageFilter.GaussianBlur(14))


def _pin(
    canvas: Image.Image, image: Image.Image, at: tuple[int, int], width: int, angle: float, caption: str = ""
) -> None:
    turned, shadow = _pinned(image, width, angle, caption)
    canvas.alpha_composite(shadow, (at[0] + 18, at[1] + 22))
    canvas.alpha_composite(turned, at)


def _kicker(picture: MissionPicture, content: PromotionContent) -> str:
    parts = ["VEAF", picture.theatre.upper(), *([content.event.upper()] if content.event else [])]
    return "  //  ".join(parts)


def _aircraft_line(picture: MissionPicture, content: PromotionContent) -> str:
    types = list(content.aircraft) or list(dict.fromkeys(flight.aircraft for flight in picture.flights))
    return " · ".join(types)


def _fit(draw: ImageDraw.ImageDraw, text: str, width: int, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    """The title font, shrunk until ``text`` holds in ``width`` pixels."""
    font = _title_font(size)
    while size > 24 and draw.textlength(text, font=font) > width:
        size -= 4
        font = _title_font(size)
    return font


def _title_lines(title: str) -> list[str]:
    """The title on two lines at its middle space when it is long, on one otherwise."""
    words = title.upper().split()
    if len(title) <= 12 or len(words) < 2:
        return [title.upper()]
    best = min(range(1, len(words)), key=lambda n: abs(len(" ".join(words[:n])) - len(" ".join(words[n:]))))
    return [" ".join(words[:best]), " ".join(words[best:])]


def render_poster(
    picture: MissionPicture, content: PromotionContent, out: Path, map_image: Path | None, photo: ReconPhoto | None
) -> None:
    """The 16:9 poster: the background, the map and the photo pinned on the right, the words on the left."""
    width, height = POSTER_SIZE
    source = Image.open(photo.image) if photo else (Image.open(map_image) if map_image else None)
    canvas = _background(source, POSTER_SIZE, 0.72).convert("RGBA")
    if map_image:
        _pin(canvas, Image.open(map_image), (1080, 120), 760, 5)
    if photo:
        _pin(canvas, Image.open(photo.image), (1170, 515), 640, -6, photo.title)
    draw = ImageDraw.Draw(canvas)
    x = 90
    draw.text((x, 150), _kicker(picture, content), fill=_GOLD, font=_font(38, bold=True))
    y = 205
    for line in _title_lines(content.title):
        font = _fit(draw, line, 960, 190)
        draw.text((x - 4, y), line, fill=_PAPER, font=font)
        y += int(font.size * 1.0) if isinstance(font, ImageFont.FreeTypeFont) else 200
    y += 20
    draw.rectangle([x, y, x + 140, y + 8], fill=_RED)
    y += 40
    for line in content.tagline[:3]:
        draw.text((x, y), line, fill=(240, 236, 226), font=_font(42, bold=True))
        y += 58
    aircraft = _aircraft_line(picture, content)
    if aircraft:
        draw.text((x, height - 160), aircraft, fill=_GOLD, font=_font(32))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, quality=92)


def render_banner(
    picture: MissionPicture, content: PromotionContent, out: Path, map_image: Path | None, photo: ReconPhoto | None
) -> None:
    """The calendar banner at 5.55:1: the kicker, the title on one line, the tagline, the pictures on the right."""
    width, height = BANNER_SIZE
    source = Image.open(photo.image) if photo else (Image.open(map_image) if map_image else None)
    canvas = _background(source, BANNER_SIZE, 0.66).convert("RGBA")
    if map_image:
        _pin(canvas, Image.open(map_image), (1580, 28), 500, 4)
    if photo:
        _pin(canvas, Image.open(photo.image), (1930, 40), 400, -5)
    draw = ImageDraw.Draw(canvas)
    x = 110
    draw.text((x, 58), _kicker(picture, content), fill=_GOLD, font=_font(40, bold=True))
    title = content.title.upper()
    draw.text((x - 4, 105), title, fill=_PAPER, font=_fit(draw, title, 1400, 170))
    draw.rectangle([x, 300, x + 120, 307], fill=_RED)
    if content.tagline:
        draw.text((x, 325), " ".join(content.tagline[:3]), fill=(240, 236, 226), font=_font(40, bold=True))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out, quality=92)


def _part_of_day(seconds: int) -> str:
    hour = seconds // 3600
    key = "night" if hour < 6 or hour >= 21 else "morning" if hour < 12 else "afternoon" if hour < 18 else "evening"
    return t(f"promotion.part_of_day.{key}")


def _mission_lines(picture: MissionPicture) -> list[str]:
    """The practical lines the built mission gives: theatre, time of day, sky; departures."""
    weather = picture.weather
    sky = (
        t("campaign.mission_deck.sky_clear")
        if weather.cover == "clear"
        else t(
            "campaign.mission_deck.sky_clouds",
            cover=t(f"campaign.mission_deck.cover.{weather.cover}"),
            base=round(metres_to_feet(weather.cloud_base), -2),
        )
    )
    lines = [f"{picture.theatre}, {_part_of_day(picture.start_time)}, {sky}"]
    if picture.airfields:
        lines.append(t("promotion.discord.dynamic_slots", bases=", ".join(a.name for a in picture.airfields)))
    elif picture.flights:
        flights = ", ".join(f"{f.callsign} ({f.aircraft})" for f in picture.flights)
        lines.append(t("promotion.discord.flights", flights=flights))
    return lines


def discord_post(picture: MissionPicture, content: PromotionContent) -> str:
    """The Discord post, in Markdown: title and evening, pitch, programme, practical lines, links, closing."""
    heading = f"# {content.title}" + (f" — {content.event}" if content.event else "")
    parts = [heading, "\n".join(content.pitch)] if content.pitch else [heading]
    if content.program:
        parts.append("\n".join([f"**{t('promotion.discord.program')}**", *content.program]))
    practical = [*_mission_lines(picture), *content.practical]
    parts.append("\n".join([f"**{t('promotion.discord.practical')}**", *(f"• {line}" for line in practical)]))
    links = []
    if content.calendar_url:
        links.append(t("promotion.discord.calendar", url=content.calendar_url))
    if content.briefing_url:
        links.append(t("promotion.discord.briefing", url=content.briefing_url))
    if links:
        parts.append("\n".join(links))
    if content.closing:
        parts.append(content.closing)
    return "\n\n".join(part for part in parts if part) + "\n"


def _first_photo(folder: Path) -> ReconPhoto | None:
    """The recon photo the poster pins: the first by order of the folder's, whatever its zone."""
    if not folder.is_dir():
        return None
    zones = []
    for sidecar in folder.glob("*.json"):
        try:
            zone = json.loads(sidecar.read_text(encoding="utf-8")).get("zone")
        except (OSError, ValueError, AttributeError):
            continue
        if zone:
            zones.append(str(zone))
    photos, _ = load_recon(folder, list(dict.fromkeys(zones)))
    every = sorted((p for group in photos.values() for p in group), key=lambda p: (p.order, p.image.name))
    return every[0] if every else None


def build_mission_promotion(
    folder: Path, content: PromotionContent, *, side: str = "blue", recon_folder: Path | None = None
) -> PromotionReport:
    """Write the poster, the calendar banner and the Discord post of a built mission.

    Args:
        folder: The mission folder, built; its briefing's maps are used when `build_mission_briefing` made them.
        content: The announcement's words.
        side: The players' side.
        recon_folder: The recon photos, as `build_mission_briefing` reads them; `docs/recon/` when omitted.

    Returns:
        Where the three files are, the post's length and the warnings.

    Raises:
        ValueError: An unbuilt mission, or a post longer than Discord takes.
    """
    miz = find_built_mission(folder)
    if miz is None:
        raise ValueError(f"No built mission in {folder}: run build_mission first.")
    warnings: list[str] = []
    with language(_mission_language(folder)):
        picture = read_mission_picture(miz, side, folder)
        post = discord_post(picture, content)
        if len(post) > DISCORD_LIMIT:
            raise ValueError(
                f"The Discord post is {len(post)} characters, Discord takes {DISCORD_LIMIT}: shorten the pitch or the programme."
            )
        maps = folder / MAPS_FOLDER
        map_image = next((maps / name for name in (COMBAT_AREA_FILE, OVERVIEW_FILE) if (maps / name).is_file()), None)
        if map_image is None:
            warnings.append("No briefing map in docs/maps/: run build_mission_briefing first, the poster has no map.")
        photo = _first_photo(folder / (recon_folder if recon_folder is not None else RECON_FOLDER))
        if photo is None:
            warnings.append("No recon photo: the poster and the banner stand on the map alone.")
        if not content.event:
            warnings.append(
                "No event date and hour given: the poster, the banner and the post carry none (never invent them)."
            )
        for url, name in ((content.calendar_url, "calendar_url"), (content.briefing_url, "briefing_url")):
            if not url:
                warnings.append(f"No {name}: the post has no such link.")
        render_poster(picture, content, folder / POSTER_FILE, map_image, photo)
        render_banner(picture, content, folder / BANNER_FILE, map_image, photo)
    (folder / DISCORD_FILE).write_text(post, encoding="utf-8")
    return PromotionReport(folder / POSTER_FILE, folder / BANNER_FILE, folder / DISCORD_FILE, len(post), warnings)
