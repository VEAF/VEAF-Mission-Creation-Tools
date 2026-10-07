"""Generate the briefing of the coming campaign mission: missions/mission-NN/briefing-mission.pptx.

The VEAF mission briefing (.prompts/new-objective-mission.fr.md, section 3), page for page as far as
a campaign mission allows: a garrison is drawn when the mission starts, so there is no target
coordinate and no flight plan to give — the objectives are the zones, their centres and the
intelligence on them.

Everything is read from the campaign (campaign.yaml, its state, briefing.yaml) and from the BUILT
mission (date, time, weather, bullseye, flights, support, carrier, QRA zone), never typed here.

Run from a VMCT checkout, its venv has everything:
    poetry -C <VMCT> run python docs/make_mission_briefing.py
"""

from __future__ import annotations

import math
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import luadata
from campaign_manager.briefing_deck import (
    _BLUE,
    _GREY,
    _HEIGHT,
    _after_colon,
    _MARGIN,
    _WIDTH,
    Block,
    Page,
    _frame,
    _run,
    _titled_slide,
    _write_page,
    paginate,
)
from campaign_manager.briefing_prose import load_prose
from campaign_manager.campaign_manager import load_campaign, load_state
from campaign_manager.intelligence import enemy_picture
from campaign_manager.models import CampaignZone
from campaign_manager.strategic_map import OWNER_COLOURS, _boxed_text, _dashed, _font, zone_position
from PIL import Image, ImageDraw
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu
from presets_injector.airfield_channels_manager import describe_airfield_channels
from veaf_libs.coordinates import latlon_to_xy, xy_to_latlon
from veaf_libs.map_tiles import CREDIT, metres_per_pixel, render_base_map
from veaf_libs.terrain_elevation import grid_for_theatre, metres_to_feet

CAMPAIGN = Path(__file__).resolve().parent.parent
NM = 1852.0


# ---------------------------------------------------------------------------
# What the campaign and the built mission say
# ---------------------------------------------------------------------------

campaign, issues = load_campaign(CAMPAIGN / "campaign.yaml")
assert campaign is not None, issues
state, issues = load_state(CAMPAIGN / "campaign-state.yaml")
assert state is not None, issues
NUMBER = state.mission + 1
prose, issues = load_prose(CAMPAIGN, campaign.missions, NUMBER)
assert prose is not None, issues
PAGE = prose.missions[NUMBER]
SUBFOLDER = CAMPAIGN / "missions" / f"mission-{NUMBER:02d}"
FOLDER = SUBFOLDER / "mission"
MIZ = max(FOLDER.glob("*.miz"), key=lambda path: path.stat().st_mtime)
_raw = zipfile.ZipFile(MIZ).read("mission").decode("utf-8")
MISSION: dict[str, Any] = luadata.unserialize(_raw.split("=", 1)[1], encoding="utf-8")
THEATRE = campaign.theatre


def latlon(x: float, y: float) -> tuple[float, float]:
    return xy_to_latlon(THEATRE, x, y)


def dms(lat: float, lon: float) -> str:
    def part(value: float, positive: str, negative: str, width: int) -> str:
        hemisphere = positive if value >= 0 else negative
        hundredths = round(abs(value) * 360000)  # rounded once, so 59.999" carries into the minute
        degrees, rest = divmod(hundredths, 360000)
        minutes, rest = divmod(rest, 6000)
        return f"{hemisphere}{degrees:0{width}d}°{minutes:02d}'{rest / 100:05.2f}\""

    return f"{part(lat, 'N', 'S', 2)} {part(lon, 'E', 'W', 3)}"


def bearing_range(frm: tuple[float, float], to: tuple[float, float]) -> tuple[int, float]:
    """True bearing (degrees) and range (nm) between two DCS x/y points (x north, y east)."""
    dx, dy = to[0] - frm[0], to[1] - frm[1]
    return round(math.degrees(math.atan2(dy, dx)) % 360), math.hypot(dx, dy) / NM


def seq(table: Any) -> list[Any]:
    """A Lua array as luadata gives it: a list, or a dict keyed 1..n."""
    if table is None:
        return []
    return list(table.values()) if isinstance(table, dict) else list(table)


def groups(side: str) -> list[dict[str, Any]]:
    found = []
    for country in seq(MISSION["coalition"][side].get("country")):
        for category in ("plane", "helicopter", "ship"):
            for group in seq((country.get(category) or {}).get("group")):
                found.append({**group, "_category": category})
    return found


def units(group: dict[str, Any]) -> list[dict[str, Any]]:
    return seq(group.get("units"))


def callsign(unit: dict[str, Any]) -> str:
    value = unit.get("callsign")
    if isinstance(value, dict):
        name = str(value.get("name", ""))
        return f"{name[:-2]} {name[-2]}-{name[-1]}" if len(name) > 2 and name[-2:].isdigit() else name
    return str(value or "")


def beacon(group: dict[str, Any]) -> str | None:
    for point in route(group):
        for task in seq(point.get("task", {}).get("params", {}).get("tasks")):
            action = task.get("params", {}).get("action", {})
            if action.get("id") == "ActivateBeacon":
                params = action["params"]
                return f"TACAN {params['channel']}{params['modeChannel']}"
    return None


def route(group: dict[str, Any]) -> list[dict[str, Any]]:
    return seq(group.get("route", {}).get("points"))


def mhz(value: float | None) -> str:
    if not value:
        return "?"
    value = float(value)
    return f"{value / 1e6:.2f}".rstrip("0").rstrip(".") if value > 1e5 else f"{value:g}"


@dataclass
class Flight:
    name: str
    callsign: str
    aircraft: str
    count: int
    base: str


blue = groups("blue")
CARRIER = next((g for g in blue if g["_category"] == "ship"), None)
CARRIER_UNIT = units(CARRIER)[0] if CARRIER else None
FLIGHTS = [
    Flight(g["name"], callsign(units(g)[0]).rsplit("-", 1)[0], units(g)[0]["type"], len(units(g)),
           CARRIER_UNIT["name"] if CARRIER_UNIT and route(g)[0].get("linkUnit") else "")
    for g in blue
    if g["_category"] in ("plane", "helicopter") and not g.get("dynSpawnTemplate") and units(g)
    and units(g)[0].get("skill") in ("Client", "Player")
]
SUPPORT = [
    g for g in blue if g["_category"] == "plane" and g.get("task") in ("AWACS", "Refueling") and units(g)[0].get("skill") not in ("Client", "Player")
]
CHANNELS = describe_airfield_channels(FOLDER)["candidates"]
DYNAMIC = [a for a in CHANNELS if a["coalition"] == campaign.player_side and a["dynamic_slots"]]
QRA_ZONES = [z for z in seq(MISSION.get("triggers", {}).get("zones")) if str(z.get("name", "")).startswith("QRA ")]
BULLSEYE = MISSION["coalition"][campaign.player_side]["bullseye"]
WEATHER = MISSION["weather"]
START = int(MISSION["start_time"])
DATE = MISSION["date"]
ELEVATION = grid_for_theatre(THEATRE)


def zone_xy(zone: CampaignZone) -> tuple[float, float]:
    return latlon_to_xy(THEATRE, *zone_position(campaign, zone))


OBJECTIVE_ZONES = []
for objective_name in ("Poti", "Khobi depot", "Senaki"):  # the order of the mission's tasks
    OBJECTIVE_ZONES.append(campaign.zone(objective_name))


# ---------------------------------------------------------------------------
# Maps
# ---------------------------------------------------------------------------


def draw_map(out: Path, points: list[tuple[float, float]], margin_m: float, *, overview: bool, focus: CampaignZone | None = None) -> Path:
    lats_lons = [latlon(x, y) for x, y in points]
    lats = [p[0] for p in lats_lons]
    lons = [p[1] for p in lats_lons]
    dlat = margin_m / 111_000
    dlon = margin_m / (111_000 * math.cos(math.radians(sum(lats) / len(lats))))
    base = render_base_map(max(lats) + dlat, min(lons) - dlon, min(lats) - dlat, max(lons) + dlon, max_pixels=1400)
    background = Image.blend(base.image, Image.new("RGB", base.image.size, (255, 255, 255)), 0.3)
    overlay = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    big, small = _font(22, bold=True), _font(16)

    def px(x: float, y: float) -> tuple[float, float]:
        return base.pixel(*latlon(x, y))

    def radius_px(x: float, y: float, metres: float) -> float:
        return metres / metres_per_pixel(latlon(x, y)[0], base.zoom)

    def dashed_circle(x: float, y: float, metres: float, colour: tuple[int, int, int]) -> None:
        cx, cy = px(x, y)
        r = radius_px(x, y, metres)
        for i in range(0, 72, 2):
            a0, a1 = math.radians(i * 5), math.radians((i + 1) * 5)
            draw.line((cx + r * math.sin(a0), cy - r * math.cos(a0), cx + r * math.sin(a1), cy - r * math.cos(a1)), fill=(*colour, 230), width=3)

    if overview:
        for a, b in campaign.connections:
            _dashed(draw, px(*zone_xy(campaign.zone(a))), px(*zone_xy(campaign.zone(b))))
        for zone in QRA_ZONES:
            dashed_circle(zone["x"], zone["y"], zone["radius"], OWNER_COLOURS["red"])
            cx, cy = px(zone["x"], zone["y"])
            r = radius_px(zone["x"], zone["y"], zone["radius"])
            text = "Alerte d'interception"
            w = draw.textbbox((0, 0), text, font=small)[2]
            # at the circle's north-west, the text running out to sea, clear of the zones' labels
            _boxed_text(draw, (cx - 0.707 * r - w - 8, cy - 0.707 * r - 10), text, small, (*OWNER_COLOURS["red"], 255))
    for zone in campaign.zones:
        x, y = zone_xy(zone)
        cx, cy = px(x, y)
        r = radius_px(x, y, zone.radius)
        colour = OWNER_COLOURS[state.zones[zone.name].owner]
        width = 4 if zone is focus else 3
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*colour, 70), outline=(*colour, 255), width=width)
        _boxed_text(draw, (cx + r + 6, cy - 12), zone.label, big, (*colour, 255))
    if overview:
        blue_colour = (*OWNER_COLOURS["blue"], 255)
        if CARRIER:
            cx, cy = px(CARRIER["x"], CARRIER["y"])
            draw.polygon([(cx, cy - 12), (cx - 9, cy + 9), (cx + 9, cy + 9)], fill=blue_colour)
            _boxed_text(draw, (cx + 12, cy - 12), f"{CARRIER_UNIT['name']} (CVN)", small, blue_colour)
        for group in SUPPORT:
            points_ = route(group)
            first = points_[0]
            if group.get("task") == "AWACS":
                dashed_circle(first["x"], first["y"], 25_000, OWNER_COLOURS["blue"])
            elif len(points_) > 1:
                draw.line((*px(first["x"], first["y"]), *px(points_[1]["x"], points_[1]["y"])), fill=blue_colour, width=5)
            cx, cy = px(first["x"], first["y"])
            _boxed_text(draw, (cx + 10, cy + 8), callsign(units(group)[0]), small, blue_colour)
        bx, by = px(BULLSEYE["x"], BULLSEYE["y"])
        for r in (8, 16):
            draw.ellipse((bx - r, by - r, bx + r, by + r), outline=(0, 0, 0, 255), width=2)
        draw.line((bx - 22, by, bx + 22, by), fill=(0, 0, 0, 255), width=2)
        draw.line((bx, by - 22, bx, by + 22), fill=(0, 0, 0, 255), width=2)
        w = draw.textbbox((0, 0), "Bullseye", font=small)[2]
        _boxed_text(draw, (bx - 26 - w, by - 28), "Bullseye", small, (0, 0, 0, 255))

    width, height = background.size
    span = 20 * NM if overview else 2000
    label = "20 nm" if overview else "2 km"
    bar = span / metres_per_pixel(sum(lats) / len(lats), base.zoom)
    x0, y0 = 20, height - 40
    draw.rectangle((x0 - 6, y0 - 16, x0 + bar + 70, y0 + 14), fill=(255, 255, 255, 220))
    draw.line((x0, y0, x0 + bar, y0), fill=(0, 0, 0, 255), width=4)
    draw.text((x0 + bar + 8, y0 - 10), label, font=small, fill=(0, 0, 0, 255))
    box = draw.textbbox((0, 0), CREDIT, font=small)
    _boxed_text(draw, (width - box[2] - 10, height - box[3] - 8), CREDIT, small, (0, 0, 0, 255))
    Image.alpha_composite(background.convert("RGBA"), overlay).convert("RGB").save(out)
    return out


# ---------------------------------------------------------------------------
# The deck
# ---------------------------------------------------------------------------

deck = Presentation()
deck.slide_width, deck.slide_height = _WIDTH, _HEIGHT


def picture_page(title: str, image: Path, notes: list[str]) -> None:
    slide = _titled_slide(deck, title)
    with Image.open(image) as im:
        ratio = im.width / im.height
    height = _HEIGHT - Emu(1250000)
    width = min(int(height * ratio), Emu(8000000))
    height = int(width / ratio)
    slide.shapes.add_picture(str(image), _MARGIN, Emu(1050000), width=Emu(width), height=Emu(height))
    frame = _frame(slide, _MARGIN + width + Emu(250000), Emu(1150000), _WIDTH - width - 3 * _MARGIN, Emu(5000000))
    first = True
    for line in notes:
        paragraph = frame.paragraphs[0] if first else frame.add_paragraph()
        first = False
        bold = line.startswith("**")
        _run(paragraph, line.strip("*"), 15 if bold else 13, bold=bold)


hours, minutes = divmod(START // 60, 60)
time_text = f"{hours:02d}h{minutes:02d} locale"
date_text = f"{DATE['Day']:02d}/{DATE['Month']:02d}/{DATE['Year']}"
wind = WEATHER["wind"]


def wind_text(layer: dict[str, Any]) -> str:
    return f"{(int(layer['dir']) + 180) % 360:03d}° / {layer['speed'] * 1.943844:.0f} kt"


clouds = WEATHER["clouds"]
sky = "ciel clair" if not clouds.get("density") and not clouds.get("preset") else f"nuages, base {metres_to_feet(clouds['base']):.0f} ft"
visibility = WEATHER["visibility"]["distance"]
kobuleti = next(a for a in CHANNELS if a["name"] == "Kobuleti")
KOB_XY = latlon_to_xy(THEATRE, *zone_position(campaign, campaign.zone("Kobuleti")))
be_brg, be_rng = bearing_range(KOB_XY, (BULLSEYE["x"], BULLSEYE["y"]))
be_lat, be_lon = latlon(BULLSEYE["x"], BULLSEYE["y"])

SECTIONS = ["Situation générale", "ATO", "Situation tactique", *[f"Situation tactique — {z.label}" for z in OBJECTIVE_ZONES], "Déroulement mission", "Plan de fréquences", "Coordonnées des objectifs"]

# 1. Cover
slide = deck.slides.add_slide(deck.slide_layouts[6])
frame = _frame(slide, _MARGIN, Emu(1700000), Emu(6800000), Emu(3200000))
_run(frame.paragraphs[0], f"{(prose.operation or campaign.name).upper()} {NUMBER}/{campaign.missions}", 40, bold=True)
_run(frame.add_paragraph(), PAGE.title, 54, bold=True, colour=_BLUE)
_run(frame.add_paragraph(), "Briefing de mission", 22, colour=_GREY)
_run(frame.add_paragraph(), f"{date_text} — {time_text}", 16, italic=True, colour=_GREY)
toc = _frame(slide, Emu(7900000), Emu(1500000), Emu(3900000), Emu(4600000))
_run(toc.paragraphs[0], "Sommaire", 20, bold=True)
for item in SECTIONS:
    _run(toc.add_paragraph(), item, 14)

# 2. General situation
context = list(prose.text("mission", "mission"))
if prose.phases[NUMBER - 1:NUMBER]:
    context += list(prose.phases[NUMBER - 1].text)
departures = []
if CARRIER_UNIT:
    departures.append(f"{CARRIER_UNIT['name']} : pont froid, Case I, le porte-avions fait route au {round(math.degrees(CARRIER_UNIT['heading'])) % 360:03d}°.")
departures += [f"{a['name']} : slots dynamiques, parking froid." for a in DYNAMIC]
threats = [f"{z.label} : {_after_colon(enemy_picture(campaign, state, z))}" for z in campaign.zones if state.zones[z.name].owner != campaign.player_side and state.zones[z.name].owner != "neutral"]
if QRA_ZONES:
    threats.insert(0, "Chasse adverse en alerte d'interception à Senaki : tout passage au-dessus de la plaine la fait décoller.")
for page in paginate(Page("1. Situation générale", [
    Block("Contexte", tuple(context)),
    Block("Mission", tuple(f"– {task.title.split(' — ')[0]}" for task in PAGE.tasks)),
    Block("Bullseye", (f"{dms(be_lat, be_lon)}, au {be_brg:03d}° / {be_rng:.0f} nm de Kobuleti.",)),
    Block("Départ", tuple(departures)),
    Block("Menace", tuple(f"– {t}" for t in threats)),
    Block("Météo", (
        f"{sky.capitalize()}, visibilité {'plus de 10 km' if visibility >= 9000 else f'{visibility / 1000:.0f} km'}, {WEATHER['season']['temperature']} °C, QNH {WEATHER['qnh']} mmHg ({WEATHER['qnh'] * 1.33322:.0f} hPa).",
        f"Vent : sol {wind_text(wind['atGround'])}, 2 000 m {wind_text(wind['at2000'])}, 8 000 m {wind_text(wind['at8000'])}.",
    )),
    Block("Horaire", (f"{date_text}, début de mission à {time_text}, peu après le lever du soleil.",)),
])):
    _write_page(deck, page)

# 3. ATO
slide = _titled_slide(deck, "2. ATO")
left = _frame(slide, _MARGIN, Emu(1150000), Emu(6600000), Emu(5200000))
_run(left.paragraphs[0], "PACKAGE", 18, bold=True)
for flight in FLIGHTS:
    p = left.add_paragraph()
    _run(p, f"{flight.callsign}  ", 15, bold=True, colour=_BLUE)
    _run(p, f"{flight.name} — {flight.count} × {flight.aircraft}", 14)
    _run(left.add_paragraph(), flight.base or "terrain", 12, italic=True, colour=_GREY)
    _run(left.add_paragraph(), "  ".join(f"{i}. ______" for i in range(1, flight.count + 1)) + "    Armement libre", 12)
for airfield in DYNAMIC:
    p = left.add_paragraph()
    _run(p, "Slots dynamiques  ", 15, bold=True, colour=_BLUE)
    _run(p, f"{airfield['name']} — appareils au choix, hélicoptères CTLD compris", 14)
    _run(left.add_paragraph(), "1. ______  2. ______  3. ______  4. ______    Armement libre", 12)
right = _frame(slide, Emu(7300000), Emu(1150000), Emu(4400000), Emu(5200000))
_run(right.paragraphs[0], "MOYENS DE SOUTIEN", 18, bold=True)
for group in SUPPORT:
    p = right.add_paragraph()
    _run(p, f"{callsign(units(group)[0])}  ", 15, bold=True, colour=RGBColor(0x8B, 0x1A, 0x1A))
    role = "AWACS" if group["task"] == "AWACS" else ("Ravitailleur de pont" if "S-3B" in units(group)[0]["type"] else "Ravitailleur (perche)")
    extra = f", {beacon(group)}" if beacon(group) else ""
    _run(p, f"{role}, {units(group)[0]['type']} — {mhz(group.get('frequency'))} MHz{extra}", 13)
_run(right.add_paragraph(), "CONTRÔLE", 18, bold=True)
if CARRIER_UNIT:
    _run(right.add_paragraph(), f"{CARRIER_UNIT['name']} : {mhz(CARRIER_UNIT.get('frequency'))} MHz, {beacon(CARRIER) or ''}", 13)
for airfield in DYNAMIC:
    f = airfield["freqs"]
    _run(right.add_paragraph(), f"{airfield['name']} : {f['uhf']:g} / {f['vhf']:g} MHz, TACAN {airfield['tacan']}", 13)

# 4. Tactical situation, overview
points = [zone_xy(z) for z in campaign.zones]
if CARRIER:
    points.append((CARRIER["x"], CARRIER["y"]))
points += [(route(g)[0]["x"], route(g)[0]["y"]) for g in SUPPORT]
overview = draw_map(SUBFOLDER / "carte-tactique.png", points, 30_000, overview=True)
picture_page("3. Situation tactique", overview, [
    "**Légende",
    "Cercles : zones, couleur du camp qui les tient",
    "Pointillés rouges : alerte d'interception",
    "Triangle : groupe aéronaval",
    "Cercle bleu : orbite AWACS ; trait bleu : hippodrome du ravitailleur",
    "**À retenir",
    "Les positions ennemies dans chaque zone ne sont pas connues : elles se découvrent en vol.",
])

# 5-7. One zoom per objective
for index, zone in enumerate(OBJECTIVE_ZONES, 4):
    x, y = zone_xy(zone)
    image = draw_map(SUBFOLDER / f"zoom-{zone.name.lower().replace(' ', '-')}.png", [(x, y)], zone.radius * 2.2, overview=False, focus=zone)
    owner = state.zones[zone.name].owner
    if owner == campaign.player_side:
        status = "Tenu par nos forces."
    elif owner == "neutral":
        status = "Aucun des deux camps n'y est installé."
    else:
        status = enemy_picture(campaign, state, zone)
    task = next((t for t in PAGE.tasks if zone.label.split()[-1] in t.title or zone.name.split()[0] in t.title), None)
    notes = [f"**{zone.label}", status, f"Zone de {zone.radius / 1000:.0f} km de rayon autour du centre."]
    if task:
        notes += ["**Tâche", task.title, *task.text]
    picture_page(f"{index}. Situation tactique — {zone.label}", image, notes)

# 8. Mission flow
next_number = 4 + len(OBJECTIVE_ZONES)
air = ["Une alerte d'interception est en place à Senaki ; elle couvre la plaine de Poti à Khobi. Type d'appareil et volume non confirmés."] if QRA_ZONES else ["Aucune activité aérienne adverse signalée."]
ad = [f"Senaki : {_after_colon(enemy_picture(campaign, state, z))}" for z in campaign.zones if z.label == "Senaki"] + ["Chaque position ennemie a sa défense aérienne d'accompagnement : rester haut ou passer vite."]
others = []
if SUPPORT:
    others.append("Ravitaillement en vol au large de Kobuleti (Arco) et sur le porte-avions (Texaco).")
others.append("Terrains de dégagement : " + ", ".join(a["name"] for a in DYNAMIC) + (f", et le {CARRIER_UNIT['name']}." if CARRIER_UNIT else "."))
others.append("Sauvetage : hélicoptère du porte-avions, et CSAR pour les pilotes éjectés.")
for page in paginate(Page(f"{next_number}. Déroulement mission", [
    Block("Objectifs principaux", tuple(f"{i}. {t.title}" for i, t in enumerate(PAGE.tasks, 1))),
    Block("Opposition aérienne", tuple(air)),
    Block("Défenses antiaériennes", tuple(ad)),
    Block("Autres informations", tuple(others)),
])):
    _write_page(deck, page)

# 9. Frequencies
lines = ["Garde : 243.0 MHz"]
for group in SUPPORT:
    lines.append(f"{callsign(units(group)[0])} : {mhz(group.get('frequency'))} MHz" + (f" — {beacon(group)}" if beacon(group) else ""))
vhf = []
if CARRIER:
    vhf.append(f"{CARRIER_UNIT['name']} (tour) : {mhz(CARRIER_UNIT.get('frequency'))} MHz — {beacon(CARRIER) or ''}, ICLS 1, Link 4 336 MHz")
for airfield in DYNAMIC:
    f = airfield["freqs"]
    lines.append(f"{airfield['name']} : {f['uhf']:g} MHz — TACAN {airfield['tacan']}")
    vhf.append(f"{airfield['name']} : {f['vhf']:g} MHz (FM {f['fm']:g} MHz)")
for page in paginate(Page(f"{next_number + 1}. Plan de fréquences", [Block("UHF", tuple(lines)), Block("VHF", tuple(vhf))])):
    _write_page(deck, page)

# 10. Objective coordinates
coords = ["Format : Lat Long, degrés minutes secondes (centre de chaque zone)."]
for zone in OBJECTIVE_ZONES:
    x, y = zone_xy(zone)
    lat, lon = zone_position(campaign, zone)
    height = ELEVATION.elevation_at(x, y) if ELEVATION else None
    alt = f" {metres_to_feet(height):.0f} ft" if height is not None else ""
    coords.append(f"{zone.label} : {dms(lat, lon)}{alt}")
coords.append("Les unités ennemies sont dispersées dans la zone : leurs positions exactes se relèvent en vol.")
for page in paginate(Page(f"{next_number + 2}. Coordonnées des objectifs", [Block(None, tuple(coords))])):
    _write_page(deck, page)

out = SUBFOLDER / "briefing-mission.pptx"
deck.save(str(out))
(Path(__file__).with_suffix(".out")).write_text(f"{out}\n{len(deck.slides)} pages\n", encoding="utf-8")
