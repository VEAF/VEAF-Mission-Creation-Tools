"""Generate the strategic briefing of the Kolkhida campaign: docs/briefing-campagne.pptx.

Reads campaign.yaml and campaign-state.yaml next to this folder, and the airbase positions shipped
with VMCT, so it can be run again after every `campaign apply` / `campaign next`.

Run: uv run --with python-pptx --with pillow --with requests --with pyyaml docs/make_briefing.py
"""

from __future__ import annotations

import math
from io import BytesIO
from pathlib import Path

import requests
import yaml
from PIL import Image, ImageDraw, ImageFont
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu, Pt

HERE = Path(__file__).resolve().parent
CAMPAIGN = HERE.parent
VMCT = Path(r"D:\dev\_VEAF\VEAF-Mission-Creation-Tools\.claude\worktrees\feat-dynamic-campaign-6d7e81")
AIRDROMES = VMCT / "src/python/veaf-tools/veaf_libs/data/airdrome-positions.yaml"
TILES = HERE / "tiles"
USER_AGENT = "VEAF-Mission-Creation-Tools campaign briefing (https://github.com/VEAF/VEAF-Mission-Creation-Tools)"

SIDE_NAME = {"blue": "bleu", "red": "rouge", "neutral": "neutre"}
SIDE_COLOUR = {"blue": (31, 95, 191), "red": (192, 57, 43), "neutral": (110, 110, 110)}
FONT = "Calibri"
BLUE_TEXT = RGBColor(0x1F, 0x5F, 0xBF)
GREY = RGBColor(0x55, 0x55, 0x55)

campaign = yaml.safe_load((CAMPAIGN / "campaign.yaml").read_text(encoding="utf-8"))
state = yaml.safe_load((CAMPAIGN / "campaign-state.yaml").read_text(encoding="utf-8"))
info = campaign["campaign"]
mission = state["mission"] + 1
airdromes = {
    a["name"]: (a["lat"], a["lon"])
    for a in yaml.safe_load(AIRDROMES.read_text(encoding="utf-8"))["theatres"][info["theatre"]]
}


#: How a zone is named to the players, when its campaign name is not French.
DISPLAY = {"Khobi depot": "Dépôt de Khobi"}


def display(name: str) -> str:
    return DISPLAY.get(name, name)


def position(zone: dict) -> tuple[float, float]:
    at = zone["at"]
    return airdromes[at["airfield"]] if "airfield" in at else (at["lat"], at["lon"])


def owner(zone: dict) -> str:
    return state["zones"][zone["name"]]["owner"]


# ---------------------------------------------------------------------------
# The strategic map
# ---------------------------------------------------------------------------
Z = 10


def tile_xy(lat: float, lon: float) -> tuple[float, float]:
    n = 2**Z
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y


def tile(x: int, y: int) -> Image.Image:
    path = TILES / f"{Z}-{x}-{y}.png"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        r = requests.get(
            f"https://tile.openstreetmap.org/{Z}/{x}/{y}.png", headers={"User-Agent": USER_AGENT}, timeout=30
        )
        r.raise_for_status()
        path.write_bytes(r.content)
    return Image.open(path).convert("RGB")


def strategic_map(out: Path) -> Path:
    points = {z["name"]: position(z) for z in campaign["zones"]}
    lats, lons = [p[0] for p in points.values()], [p[1] for p in points.values()]
    x0, y0 = tile_xy(max(lats) + 0.12, min(lons) - 0.25)
    x1, y1 = tile_xy(min(lats) - 0.16, max(lons) + 0.25)
    tx0, ty0, tx1, ty1 = int(x0), int(y0), int(x1), int(y1)
    canvas = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
    for tx in range(tx0, tx1 + 1):
        for ty in range(ty0, ty1 + 1):
            canvas.paste(tile(tx, ty), ((tx - tx0) * 256, (ty - ty0) * 256))
    crop = (int((x0 - tx0) * 256), int((y0 - ty0) * 256), int((x1 - tx0) * 256), int((y1 - ty0) * 256))
    canvas = canvas.crop(crop)
    # wash the background so the zones stand out
    canvas = Image.blend(canvas, Image.new("RGB", canvas.size, (255, 255, 255)), 0.35)

    def px(lat: float, lon: float) -> tuple[float, float]:
        x, y = tile_xy(lat, lon)
        return (x - x0) * 256, (y - y0) * 256

    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    font = ImageFont.truetype("calibrib.ttf", 22)
    small = ImageFont.truetype("calibri.ttf", 16)
    for a, b in campaign["connections"]:
        pa, pb = px(*points[a]), px(*points[b])
        steps = int(math.dist(pa, pb) // 12)
        for i in range(0, steps, 2):
            s, e = i / steps, min((i + 1) / steps, 1)
            draw.line(
                [(pa[0] + (pb[0] - pa[0]) * s, pa[1] + (pb[1] - pa[1]) * s),
                 (pa[0] + (pb[0] - pa[0]) * e, pa[1] + (pb[1] - pa[1]) * e)],
                fill=(40, 40, 40, 200),
                width=3,
            )
    for zone in campaign["zones"]:
        lat, lon = points[zone["name"]]
        cx, cy = px(lat, lon)
        metres_per_px = 156543.03 * math.cos(math.radians(lat)) / 2**Z
        r = zone.get("radius", 2000) / metres_per_px
        colour = SIDE_COLOUR[owner(zone)]
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*colour, 90), outline=(*colour, 255), width=3)
        label = display(zone["name"])
        tx, ty = cx + r + 6, cy - 12
        box = draw.textbbox((tx, ty), label, font=font)
        draw.rectangle((box[0] - 4, box[1] - 2, box[2] + 4, box[3] + 2), fill=(255, 255, 255, 220))
        draw.text((tx, ty), label, font=font, fill=(*colour, 255))
    # scale bar: 20 km
    lat_mid = sum(lats) / len(lats)
    bar = 20000 / (156543.03 * math.cos(math.radians(lat_mid)) / 2**Z)
    bx, by = 20, canvas.size[1] - 50
    draw.rectangle((bx - 6, by - 26, bx + bar + 60, by + 14), fill=(255, 255, 255, 220))
    draw.line((bx, by, bx + bar, by), fill=(0, 0, 0, 255), width=4)
    draw.text((bx + bar + 8, by - 10), "20 km", font=small, fill=(0, 0, 0, 255))
    draw.text((bx, by - 26), f"≈ {20 / 1.852:.0f} nm", font=small, fill=(0, 0, 0, 255))
    credit = "© OpenStreetMap contributors"
    cb = draw.textbbox((0, 0), credit, font=small)
    cxp, cyp = canvas.size[0] - cb[2] - 10, canvas.size[1] - cb[3] - 8
    draw.rectangle((cxp - 4, cyp - 2, cxp + cb[2] + 4, cyp + cb[3] + 2), fill=(255, 255, 255, 220))
    draw.text((cxp, cyp), credit, font=small, fill=(0, 0, 0, 255))
    image = Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB")
    image.save(out)
    return out


# ---------------------------------------------------------------------------
# The deck, after the VEAF briefing template: 16:9, white, bold title top left, left-aligned
# ---------------------------------------------------------------------------
deck = Presentation()
deck.slide_width, deck.slide_height = Emu(12192000), Emu(6858000)
BLANK = deck.slide_layouts[6]
W, H = deck.slide_width, deck.slide_height
M = Emu(457200)


def text_box(slide, left, top, width, height):
    frame = slide.shapes.add_textbox(left, top, width, height).text_frame
    frame.word_wrap = True
    return frame


def run(paragraph, text, size, bold=False, italic=False, colour=None):
    r = paragraph.add_run()
    r.text = text
    r.font.name, r.font.size, r.font.bold, r.font.italic = FONT, Pt(size), bold, italic
    if colour is not None:
        r.font.color.rgb = colour
    return r


def page(title: str):
    slide = deck.slides.add_slide(BLANK)
    run(text_box(slide, M, Emu(300000), W - 2 * M, Emu(700000)).paragraphs[0], title, 30, bold=True)
    return slide


def body(slide, sections, left=None, top=Emu(1150000), width=None, size=15):
    frame = text_box(slide, left or M, top, width or W - 2 * M, H - top - Emu(300000))
    first = True
    for heading, lines in sections:
        p = frame.paragraphs[0] if first else frame.add_paragraph()
        first = False
        if heading:
            run(p, heading, size + 2, bold=True)
            p.space_before = Pt(8)
            p = frame.add_paragraph()
        for i, line in enumerate(lines):
            if i:
                p = frame.add_paragraph()
            run(p, line, size)
    return frame


# ---------------------------------------------------------------------------
# What the campaign records, read again at every run
# ---------------------------------------------------------------------------
held = {side: [z["name"] for z in campaign["zones"] if owner(z) == side] for side in SIDE_NAME}
rules = campaign.get("rules", {})
output = rules.get("logistics_output", {"armor": 2, "air_defense": 1, "transport": 1})
repairs = rules.get("repairs_per_mission", 4)
capture_minutes = info.get("capture_seconds", 120) // 60
left = info["missions"] - state["mission"]
victory = []
for o in info["objectives"]:
    if "capture" in o:
        victory.append("tenir " + ", ".join(o["capture"]))
    else:
        victory.append(f"avoir détruit le {display(o['destroy']['zone'])[0].lower() + display(o['destroy']['zone'])[1:]}")


def reserve_text(side: str) -> str:
    r = state["sides"][side]["reserve"]
    return (f"{r['armor']} unités blindées, {r['air_defense']} de défense aérienne, "
            f"{r['transport']} de transport")


#: Our own positions: we know what we hold.
OWN = {"outpost": "détachement de la valeur d'une compagnie renforcée",
       "airfield": "base aérienne défendue, avec sa défense aérienne longue portée"}

#: What the intelligence says of an enemy position, by what the position is, and how reliable it is.
#: Never a count: the composition is drawn when the mission starts, and found in flight.
INTEL = {
    "airfield": ("position principale. Activité blindée et mécanisée signalée. Défense aérienne longue "
                 "portée probable, type non confirmé", "imagerie, plutôt fiable"),
    "logistics": ("centre logistique actif, mouvements de camions quotidiens. Protection du site de "
                  "nature inconnue", "sources locales, non recoupées"),
    "outpost": ("présence signalée, volume et nature inconnus", "renseignement fragmentaire"),
}


def zones_text(side: str) -> list[str]:
    lines = []
    for z in campaign["zones"]:
        if owner(z) != side:
            continue
        if side == "blue":
            lines.append(f"– {z['name']} : {OWN.get(z['size'], z['size'])}.")
        else:
            what, source = INTEL["logistics" if z.get("kind") == "logistics" else z["size"]]
            lines.append(f"– {display(z['name'])} : {what} ({source}).")
    return lines


SECTIONS = [
    "Situation stratégique",
    "Situation militaire",
    "Carte stratégique",
    "Mission et intention",
    "Objectifs de la campagne",
    "Concept d'opération",
    "Règles d'engagement",
    f"Mission {mission}",
    "Annexe — Règles de la campagne",
]

# 1. Cover
slide = deck.slides.add_slide(BLANK)
frame = text_box(slide, M, Emu(1700000), Emu(6600000), Emu(3000000))
run(frame.paragraphs[0], "OPÉRATION", 40, bold=True)
run(frame.add_paragraph(), info["name"].upper(), 66, bold=True, colour=BLUE_TEXT)
run(frame.add_paragraph(), "Briefing de situation — campagne", 22, colour=GREY)
run(frame.add_paragraph(), f"Caucase — {info['missions']} missions — situation avant la mission {mission}", 16,
    italic=True, colour=GREY)
toc = text_box(slide, Emu(7700000), Emu(1500000), Emu(4100000), Emu(4200000))
run(toc.paragraphs[0], "Sommaire", 20, bold=True)
for number, item in enumerate(SECTIONS, 1):
    run(toc.add_paragraph(), item if item.startswith("Annexe") else f"{number}. {item}", 15)

# 2. Strategic situation: political, economic
body(page("1. Situation stratégique"), [
    ("Situation politique", [
        "– Il y a dix jours, sans déclaration préalable, les forces rouges ont franchi l'Inguri et pris "
        "pied dans la plaine de Colchide. Le gouvernement de Tbilissi a demandé l'assistance de la coalition, "
        "qui a obtenu un mandat limité : rétablir la ligne de cessez-le-feu, sans porter la guerre au-delà de l'Inguri.",
        "– Le temps joue contre nous : une négociation s'ouvre, et chaque kilomètre tenu par l'adversaire à "
        "son ouverture lui sera acquis. La coalition doit avoir repris l'initiative avant.",
        "– L'opinion des pays de la coalition suit de près les pertes civiles : une victoire obtenue en "
        "rasant les villes de la plaine serait une défaite politique.",
    ]),
    ("Situation économique", [
        "– Poti est le premier port de commerce du pays et le terminal de la voie ferrée vers Tbilissi. "
        "Neutralisé depuis le début des combats, il ne tourne plus : le pays est coupé de la mer Noire au nord de Batumi.",
        "– La plaine de Colchide est le grenier et le verger de la Géorgie occidentale. Ses routes et ses "
        "ponts sont la seule liaison terrestre entre la côte et l'intérieur.",
        "– L'adversaire vit sur un approvisionnement étiré depuis l'Inguri, regroupé au dépôt de Khobi. "
        "C'est sa faiblesse.",
    ]),
], size=14)

# 3. Military situation: enemy, friendly
slide = page("2. Situation militaire")
body(slide, [
    ("Forces ennemies", [
        "– Un groupement interarmes à l'effectif réduit, arrêté faute de carburant et de munitions.",
        *zones_text("red"),
        "– Réserves : volume inconnu. Le renseignement estime qu'elles transitent toutes par Khobi.",
        "– Mode d'action le plus probable : tenir Senaki sous sa défense aérienne, reconstituer ses forces "
        "grâce à Khobi, puis reprendre l'offensive vers Poti et Kobuleti.",
    ]),
], width=W // 2 - M, size=13)
body(slide, [
    ("Forces amies", [
        "– La coalition tient le sud de la côte et ses deux aérodromes, d'où partent nos vols.",
        *zones_text("blue"),
        f"– Réserves : {reserve_text('blue')}. Elles sont limitées : nos pertes ne seront pas compensées rapidement.",
        "– Notre avantage est aérien. Au sol, nous ne pouvons pas nous offrir une guerre d'usure.",
    ]),
    ("Zone neutre", [f"– {display(name)} : abandonné par les deux camps." for name in held["neutral"]]),
], left=W // 2 + Emu(100000), width=W // 2 - M - Emu(100000), size=13)
note = text_box(slide, M, H - Emu(650000), W - 2 * M, Emu(400000))
run(note.paragraphs[0], "Le renseignement sur l'ennemi est partiel : ce qui sera vu en vol fera foi.", 11, italic=True, colour=GREY)

# 4. Strategic map
slide = page("3. Carte stratégique")
image = strategic_map(HERE / "carte-strategique.png")
with Image.open(image) as im:
    ratio = im.width / im.height
height = H - Emu(1250000)
slide.shapes.add_picture(str(image), M, Emu(1050000), height=height)
legend = text_box(slide, M + int(height * ratio) + Emu(300000), Emu(1200000), Emu(3600000), Emu(4500000))
run(legend.paragraphs[0], "Légende", 18, bold=True)
for side in ("blue", "red", "neutral"):
    p = legend.add_paragraph()
    run(p, "● ", 18, colour=RGBColor(*SIDE_COLOUR[side]))
    run(p, f"{'Neutre' if side == 'neutral' else 'Tenu par les ' + SIDE_NAME[side] + 's'}", 15)
run(legend.add_paragraph(), "- - -  axes de progression", 15)

# 5. Mission and intent
body(page("4. Mission et intention"), [
    ("Mission", [
        f"En {info['missions']} missions, la coalition reprend Senaki et détruit le dépôt logistique de Khobi, "
        "afin de briser l'offensive rouge dans la plaine de Colchide et de rétablir la ligne de l'Inguri.",
    ]),
    ("Intention du commandement", [
        "– But : priver l'adversaire de sa capacité à reprendre l'offensive, avant l'ouverture des négociations.",
        "– Effet majeur : priver Senaki de son soutien logistique. Sans Khobi, l'adversaire ne peut plus "
        "compenser ses pertes ni reprendre l'offensive.",
        "– Méthode : prendre Poti pour fixer la côte, user la défense aérienne de Senaki, détruire Khobi, "
        "puis prendre Senaki.",
        "– État final recherché : Senaki et Poti tenues par la coalition, Khobi détruit, nos forces en état "
        "de tenir le terrain conquis, les villes et le port épargnés.",
    ]),
], size=14)

# 6. Objectives, by nature
body(page("5. Objectifs de la campagne"), [
    ("Politiques", [
        "– Rétablir l'autorité du gouvernement sur la plaine de Colchide jusqu'à l'Inguri.",
        "– Arriver à la négociation en position de force, sans avoir franchi l'Inguri.",
        "– Limiter les pertes civiles et les destructions : c'est la condition du soutien de l'opinion.",
    ]),
    ("Militaires", [
        "– Reprendre l'aérodrome de Senaki.",
        "– Détruire le dépôt logistique de Khobi.",
        "– Préserver nos forces : notre réserve est trop maigre pour une guerre d'usure.",
    ]),
    ("Économiques", [
        "– Rouvrir le port de Poti, intact.",
        "– Rendre la plaine et ses axes de communication à l'activité civile.",
    ]),
    ("Conditions de victoire", [
        f"Avant l'ouverture des négociations, soit au terme de la mission {info['missions']} : " + " et ".join(victory) + ".",
    ]),
], size=13)

# 7. Concept of operations, phase by phase
body(page("6. Concept d'opération"), [
    ("Phase 1 — mission 1 : la porte de Poti", [
        "Prendre Poti pour verrouiller la côte et la route de Senaki. Commencer l'attrition du dépôt de Khobi. "
        "Reconnaître Senaki et localiser sa défense aérienne longue portée.",
    ]),
    ("Phase 2 — mission 2 : couper le ravitaillement", [
        "Détruire le dépôt de Khobi. Poursuivre la suppression des défenses aériennes de "
        "Senaki pour ouvrir le ciel à la phase 3.",
    ]),
    ("Phase 3 — mission 3 : Senaki", [
        "Réduire les défenses de Senaki, puis y engager des troupes héliportées pour s'emparer de l'aérodrome.",
    ]),
    ("Points de vigilance", [
        "– Le plan sera réajusté après chaque mission en fonction des résultats obtenus.",
        "– Zugdidi n'est pas un objectif. Sa garnison peut couvrir Khobi et Senaki : ne pas s'y engager sans raison.",
    ]),
], size=14)

# 8. Rules of engagement
body(page("7. Règles d'engagement"), [
    ("Ciblage", [
        "– Identification positive de toute cible avant le tir. En cas de doute, on ne tire pas.",
        "– Cibles autorisées : les unités militaires rouges, au sol et en l'air, et leurs installations "
        "militaires.",
        "– Aucun tir au nord de l'Inguri.",
    ]),
    ("Protection des civils et des infrastructures", [
        "– Pas de bombardement de zone dans les agglomérations de Poti, Senaki, Khobi et Zugdidi : "
        "armement guidé, axes d'attaque choisis pour épargner les habitations.",
        "– Infrastructures à préserver : le port de Poti, la piste et les installations de Senaki, "
        "les ponts de la plaine. Nous en aurons besoin.",
        "– Les dommages collatéraux feront l'objet d'un compte rendu après chaque mission.",
    ]),
    ("Autodéfense", [
        "– Le droit de légitime défense n'est jamais restreint : une menace qui illumine ou tire est engagée "
        "sans autre autorisation.",
    ]),
], size=14)

# 10. Mission 1
body(page(f"8. Mission {mission} — La porte de Poti"), [
    ("1. Prendre Poti — priorité 1", [
        "Sécuriser le port avec des troupes héliportées et en chasser toute présence ennemie. "
        "Une unité de la réserve viendra ensuite le tenir.",
    ]),
    ("2. Frapper le dépôt de Khobi — priorité 2", [
        "Commencer l'attrition du dépôt : chaque moyen détruit à Khobi manquera au front. "
        "Sa destruction complète privera l'adversaire de ses renforts.",
    ]),
    ("3. Reconnaître Senaki — opportunité", [
        "Confirmer la présence et le type de la défense aérienne longue portée, et commencer à l'user. "
        "Ne pas s'engager au sol sans couverture : pas de pertes inutiles dès la première mission.",
    ]),
])


# 9. Support and campaign rules
body(page("Annexe — Règles de la campagne"), [
    ("Prendre une zone", [
        "– Une zone qui perd toute sa garnison devient neutre.",
        f"– Le premier camp qui y tient le terrain seul pendant {capture_minutes} minutes la prend : troupes ou "
        "véhicules héliportés CTLD, convoi, hélicoptère posé. Un avion en vol ne compte pas.",
        "– La zone prise reçoit aussitôt une garnison de son nouveau camp, prise sur sa réserve.",
    ]),
    ("Entre deux missions", [
        f"– Chaque dépôt logistique ajoute à la réserve de son camp {output['armor']} blindés, "
        f"{output['air_defense']} défense aérienne et {output['transport']} transport.",
        f"– Chaque camp répare jusqu'à {repairs} unités perdues, prises sur sa réserve.",
        "– Une zone neutre bordée par un seul camp est reprise par lui. Poti touche les deux camps : "
        "personne ne la prendra d'office.",
    ]),
    ("Continuité", [
        "– Les pertes, les zones prises et le décor détruit sont enregistrés en vol et reportés sur la "
        "mission suivante. Ce qui est détruit le reste.",
    ]),
], size=14)

out = HERE / "briefing-campagne.pptx"
deck.save(out)
print(out)
