"""MCP prompts a pilot fills in: four ready-made requests (FEAT-MCP-PROMPTS).

A client such as Cherry Studio lists the server's prompts, asks the user for each argument in a dialog,
then inserts the text returned here in its input box, where the user rereads it and sends it. The model
receives that text. So each function below only fills a French sentence; it decides nothing a tool would.

The texts come from the blocks of the "Marteau du Golan" tutorial that worked on a local model: positions
are DCS ``x``/``y`` already converted (``x`` is the northing, ``y`` the easting, as in a mission table;
``docs/agents/dcs-coordinates.md``), the mission folder is explicit, and the mission is validated and
built once, at the end. An action is written between backticks and nothing else is: a test reads the
backticks to check that each action exists, in the catalogue both profiles serve, and that the authoring
guide teaches it.
"""

from typing import Annotated, Any

from pydantic import BeforeValidator, Field

#: The folder a new mission goes to when the user names none.
DEFAULT_MISSIONS_ROOT = "C:\\VEAF-Missions"
#: What a sentence says of a detail the user left blank: the model decides, and says so.
_LEFT_TO_THE_MODEL = "à toi de choisir"
#: The closing instruction of every prompt: one build, at the end.
_BUILD_ONCE = (
    "Valide (`validate_mission`) et construis (`build_mission`) une seule fois, quand tout est placé, puis résume."
)


def _blank_to_none(value: Any) -> Any:
    """Read an empty or blank string as no value, the way a client sends a field the user left empty."""
    if isinstance(value, str) and not value.strip():
        return None
    return value


def _decimal_point(value: Any) -> Any:
    """Accept a decimal comma (``35,55``) in a number typed by a pilot."""
    return value.strip().replace(",", ".") if isinstance(value, str) else value


#: A number the user may leave out.
OptionalNumber = Annotated[float | None, BeforeValidator(_blank_to_none), BeforeValidator(_decimal_point)]
#: A whole number the user may leave out.
OptionalInt = Annotated[int | None, BeforeValidator(_blank_to_none)]
#: A required number, typed with a decimal comma or not.
RequiredNumber = Annotated[float, BeforeValidator(_decimal_point)]


def _text(value: str) -> str:
    """Return a free-text argument trimmed; the empty string when the user left it blank."""
    return value.strip()


def _num(value: float) -> str:
    """Write a number the way the actions read it: ``-185000``, not ``-185000.0``."""
    return str(int(value)) if float(value).is_integer() else str(value)


def _side(camp: str, default: str) -> str:
    """Return the coalition the user named, or the default one when blank."""
    return _text(camp) or default


def nouvelle_mission(
    nom: Annotated[str, Field(description="Nom de la mission, sans espace ni accent (ex. Marteau-du-Golan)")],
    carte: Annotated[str, Field(description="Carte DCS : Caucase, Syrie, Golfe Persique, Allemagne guerre froide…")],
    date: Annotated[str, Field(description="Date de la mission (ex. 16 avril 2024). Vide : le modèle choisit")] = "",
    heure: Annotated[str, Field(description="Heure locale de départ (ex. 15h00). Vide : le modèle choisit")] = "",
    meteo: Annotated[
        str, Field(description="Météo (ex. nuages à 3 000 m, vent d'ouest 12 nœuds). Vide : le modèle choisit")
    ] = "",
    scenario: Annotated[
        str, Field(description="Scénario en quelques phrases : qui attaque, quoi, combien de pilotes")
    ] = "",
    dossier: Annotated[
        str, Field(description="Dossier de la mission, vide ou à créer. Vide : C:\\VEAF-Missions\\<nom>")
    ] = "",
) -> str:
    """Return the request that creates a new mission from its name, its map and a few details.

    Args:
        nom: The mission's name.
        carte: The DCS map.
        date: The mission's date; blank leaves it to the model.
        heure: The local start time; blank leaves it to the model.
        meteo: The weather; blank leaves it to the model.
        scenario: What the mission is about; blank leaves it to the model.
        dossier: The mission folder; blank means ``C:\\VEAF-Missions\\<nom>``.

    Returns:
        The French text the client puts in the user's input box.
    """
    nom = _text(nom)
    folder = _text(dossier) or f"{DEFAULT_MISSIONS_ROOT}\\{nom}"
    return (
        f"Crée une mission sur la carte {_text(carte)} nommée {nom}, modèle standard, en français.\n"
        f"Dossier de la mission : {folder}.\n"
        f"Date : {_text(date) or _LEFT_TO_THE_MODEL}. Heure locale : {_text(heure) or _LEFT_TO_THE_MODEL}.\n"
        f"Météo : {_text(meteo) or _LEFT_TO_THE_MODEL} (visibilité bonne, vent modéré : des hélicoptères peuvent voler).\n"
        f"Scénario : {_text(scenario) or _LEFT_TO_THE_MODEL}.\n"
        "Commence par lire le guide (`describe_authoring_guide`) puis les limites connues "
        "(`describe_known_limitations`), et suis la recette du guide appel par appel.\n"
        "Les positions que je donne sont des x/y DCS déjà convertis : ne les passe pas au géocodeur.\n"
        f"{_BUILD_ONCE}"
    )


def ajouter_qra(
    mission: Annotated[str, Field(description="Dossier de la mission (ex. C:\\VEAF-Missions\\Marteau-du-Golan)")],
    base: Annotated[str, Field(description="Base aérienne d'où décollent les intercepteurs (ex. Mezzeh)")],
    x: Annotated[RequiredNumber, Field(description="x DCS du centre de la zone protégée (nord-sud, ex. -185000)")],
    y: Annotated[RequiredNumber, Field(description="y DCS du centre de la zone protégée (est-ouest, ex. 20000)")],
    rayon_km: Annotated[OptionalNumber, Field(description="Rayon de la zone en km. Vide : 30")] = None,
    appareils: Annotated[
        str, Field(description="Appareils (ex. 2 MiG-29S, et 4 s'il y a au moins 4 avions ennemis)")
    ] = "",
    delai_s: Annotated[
        OptionalInt, Field(description="Délai en secondes entre la première intrusion et le décollage. Vide : aucun")
    ] = None,
    camp: Annotated[str, Field(description="Camp de la QRA : rouge ou bleu. Vide : rouge")] = "",
) -> str:
    """Return the request that adds a QRA (interceptors that scramble when an enemy enters an area).

    The delay is counted from the first intrusion into the zone, not from the mission's start: the
    sentence says so, since that is the sense of ``delay_before_activating``.

    Args:
        mission: The mission folder.
        base: The airfield the interceptors take off from.
        x: DCS ``x`` of the zone's centre.
        y: DCS ``y`` of the zone's centre.
        rayon_km: The zone's radius in km; blank means 30.
        appareils: The aircraft; blank leaves them to the model.
        delai_s: Seconds from the first intrusion to the scramble; blank means none.
        camp: The QRA's coalition; blank means red.

    Returns:
        The French text the client puts in the user's input box.
    """
    base = _text(base)
    radius = _num(rayon_km) if rayon_km else "30"
    aircraft = (
        _text(appareils)
        or f"des intercepteurs de ton choix ({_LEFT_TO_THE_MODEL}, vérifie le type avec `list_unit_types`)"
    )
    if delai_s:
        timing = (
            f"Elle décolle {delai_s} s après la première intrusion dans sa zone, pas depuis le début de la mission : "
            "l'attente démarre à l'intrusion (paramètre delay_before_activating)."
        )
    else:
        timing = "Elle décolle dès la première intrusion dans sa zone."
    return (
        f"Dans la mission {_text(mission)}, ajoute une QRA {_side(camp, 'rouge')} (`create_qra`) qui ne décolle pas pour des hélicoptères.\n"
        f"QRA-{base} : base de {base}, zone de {radius} km centrée sur x {_num(x)}, y {_num(y)} (coordonnées DCS), {aircraft}.\n"
        f"{timing}\n"
        f"{_BUILD_ONCE}"
    )


def ajouter_zone_de_combat(
    mission: Annotated[str, Field(description="Dossier de la mission (ex. C:\\VEAF-Missions\\Marteau-du-Golan)")],
    nom: Annotated[str, Field(description="Nom de la zone, sans espace (ex. SA6Sasa)")],
    x: Annotated[RequiredNumber, Field(description="x DCS du centre de la zone (nord-sud, ex. -188500)")],
    y: Annotated[RequiredNumber, Field(description="y DCS du centre de la zone (est-ouest, ex. 12500)")],
    rayon: Annotated[OptionalInt, Field(description="Rayon de la zone en mètres. Vide : 1000")] = None,
    contenu: Annotated[
        str, Field(description="Ce qu'elle contient (ex. une batterie SA-6, 2 groupes de blindés)")
    ] = "",
    camp: Annotated[str, Field(description="Camp de la zone : rouge ou bleu. Vide : rouge")] = "",
) -> str:
    """Return the request that adds a VEAF combat zone.

    Args:
        mission: The mission folder.
        nom: The zone's name.
        x: DCS ``x`` of the zone's centre.
        y: DCS ``y`` of the zone's centre.
        rayon: The radius in metres; blank means 1000.
        contenu: What the zone holds; blank leaves it to the model.
        camp: The zone's coalition; blank means red.

    Returns:
        The French text the client puts in the user's input box.
    """
    content = _text(contenu) or f"du contenu adapté à la carte ({_LEFT_TO_THE_MODEL})"
    return (
        f"Dans la mission {_text(mission)}, ajoute une zone de combat VEAF (`create_combat_zone`) nommée {_text(nom)}.\n"
        f"Position : x {_num(x)}, y {_num(y)} (coordonnées DCS). Rayon : {rayon or 1000} m. Camp : {_side(camp, 'rouge')}.\n"
        f"Contenu : {content}.\n"
        "Chaque groupe est un alias VEAF (`list_shortcuts` donne le bon), jamais des unités placées à la main.\n"
        "Écris un court texte de briefing pour la zone.\n"
        f"{_BUILD_ONCE}"
    )


def ajouter_jtac(
    mission: Annotated[str, Field(description="Dossier de la mission (ex. C:\\VEAF-Missions\\Marteau-du-Golan)")],
    x: Annotated[RequiredNumber, Field(description="x DCS de la position du JTAC (nord-sud, ex. -206900)")],
    y: Annotated[RequiredNumber, Field(description="y DCS de la position du JTAC (est-ouest, ex. -16700)")],
    code_laser: Annotated[OptionalInt, Field(description="Code laser à 4 chiffres. Vide : 1688")] = None,
    frequence: Annotated[OptionalNumber, Field(description="Fréquence radio en MHz (ex. 35,55). Vide : 35,55")] = None,
    modulation: Annotated[str, Field(description="Modulation : FM, AM ou UHF. Vide : FM")] = "",
    nom: Annotated[str, Field(description="Nom du groupe du JTAC. Vide : JTAC-1")] = "",
    lieu: Annotated[str, Field(description="Lieu, pour la description (ex. Tel Abu Nada). Vide : aucun")] = "",
    camp: Annotated[str, Field(description="Camp du JTAC : bleu ou rouge. Vide : bleu")] = "",
) -> str:
    """Return the request that adds a JTAC: a Hummer, and its line in the ASSETS module.

    Args:
        mission: The mission folder.
        x: DCS ``x`` of the JTAC's position.
        y: DCS ``y`` of the JTAC's position.
        code_laser: The 4-digit laser code; blank means 1688.
        frequence: The radio frequency in MHz; blank means 35.55.
        modulation: ``FM``, ``AM`` or ``UHF``; blank means FM.
        nom: The group's name; blank means ``JTAC-1``.
        lieu: The place, for the description; blank leaves it out.
        camp: The JTAC's coalition; blank means blue.

    Returns:
        The French text the client puts in the user's input box.
    """
    name = _text(nom) or "JTAC-1"
    code = code_laser or 1688
    radio = f"{_text(modulation).upper() or 'FM'} {_num(frequence) if frequence else '35.55'}"
    where = f" à {_text(lieu)}" if _text(lieu) else ""
    return (
        f"Dans la mission {_text(mission)}, ajoute un JTAC{where} : un Hummer {_side(camp, 'bleu')} (`add_group`) "
        f"à x {_num(x)}, y {_num(y)} (coordonnées DCS), à cette position exacte, nommé {name}, "
        f"code laser {code}, fréquence {radio}.\n"
        f"Déclare-le dans le module ASSETS (`set_mission_module`) : le groupe, le code laser, la fréquence et la modulation. "
        "La valeur remplace tout le bloc ASSETS : garde les assets qu'il liste déjà.\n"
        f"{_BUILD_ONCE}"
    )


#: The prompts the server registers, in the order a client lists them, each with the description it shows.
PROMPTS: tuple[tuple[Any, str], ...] = (
    (nouvelle_mission, "Nouvelle mission : son nom, sa carte, sa date, sa météo et son scénario."),
    (ajouter_qra, "Ajouter une QRA : des intercepteurs qui décollent quand un ennemi entre dans une zone."),
    (ajouter_zone_de_combat, "Ajouter une zone de combat VEAF : sa position, son rayon et son contenu."),
    (ajouter_jtac, "Ajouter un JTAC : sa position, son code laser et sa fréquence."),
)
