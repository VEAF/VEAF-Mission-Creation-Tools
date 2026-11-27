"""MCP prompts a pilot fills in: one per kind of mission (FEAT-MCP-PROMPTS).

A client such as Cherry Studio lists the server's prompts, asks the user for each argument in a dialog,
then inserts the text returned here in its input box, where the user rereads and sends it. The model
receives that text.

Each prompt answers the first question of the authoring guide, *which kind of mission?*, for the user:
a one-shot mission with objectives, an Open Training, a persistent campaign. It **does not copy** the
mission prompt of that kind: it gathers the closed answers the prompt asks first (map, era, aircraft...)
and tells the model to load the prompt with ``describe_mission_prompt`` and follow it from its first
section. The guide and the mission prompts stay the single source. What needs a discussion, a table to
validate or a measure stays with the mission prompt: scenario, objectives, front, zones, escorts, and
the date, time and weather, which the prompt proposes (a persistent campaign fixes none at all).

An action is written between backticks and nothing else is: a test reads the backticks to check that
each action exists, in the catalogue both profiles serve, and that the authoring guide teaches it.
"""

from typing import Annotated, Any

from pydantic import Field

#: The languages a mission prompt is written in (`describe_mission_prompt`'s `lang`).
LANGUAGES = ("fr", "en")


def _text(value: str) -> str:
    """Return a free-text argument trimmed; the empty string when the user left it blank."""
    return value.strip()


def _language(langue: str) -> str:
    """Return the language asked for, ``fr`` when blank.

    Args:
        langue: ``fr`` or ``en``, any case, or blank.

    Returns:
        The language code.

    Raises:
        ValueError: When the value is neither ``fr`` nor ``en``.
    """
    value = _text(langue).lower() or LANGUAGES[0]
    if value not in LANGUAGES:
        raise ValueError(f"langue must be one of {LANGUAGES}, got {langue!r}")
    return value


def _given(label: str, value: str, default: str | None = None) -> str:
    """Write one answer the user gave, or the default one, or nothing when there is neither.

    Args:
        label: What the answer is about, at the start of the line.
        value: What the user typed; may be blank.
        default: What the prompt applies when the user typed nothing; ``None`` for no line at all.

    Returns:
        The line, with its trailing newline, or the empty string.
    """
    text = _text(value) or default
    return f"- {label} : {text}.\n" if text else ""


def _request(title: str, kind: str, langue: str, answers: str, dossier: str, left_to_the_prompt: str) -> str:
    """Build the short message every mission prompt returns.

    Args:
        title: The kind of mission, in the user's words.
        kind: The `describe_mission_prompt` kind that holds its prompt.
        langue: The language of the mission and of that prompt.
        answers: The lines of answers the user already gave.
        dossier: The folder the user named, blank for none.
        left_to_the_prompt: What the mission prompt still asks, in a clause.

    Returns:
        The French text the client puts in the user's input box.
    """
    lang = _language(langue)
    folder = _text(dossier)
    where = f"Dossier de la mission : {folder}." if folder else "Dossier : demande-moi où le créer."
    return (
        f"Je veux créer une {title}.\n"
        f'Charge le prompt de ce type avec `describe_mission_prompt` (kind : "{kind}", lang : "{lang}") '
        "et suis-le dès sa première section, après avoir lu le guide (`describe_authoring_guide`).\n"
        "Mes réponses aux premières questions du prompt (ne me les repose pas) :\n"
        f"{answers}"
        f"- Langue de la mission et de ses textes : {lang}.\n"
        f"{where}\n"
        f"Le reste ({left_to_the_prompt}), le prompt me le demande ou le propose : une question à la fois."
    )


def mission_one_shot(
    carte: Annotated[
        str, Field(description="Carte DCS de la mission : Caucase, Syrie, Golfe Persique, Allemagne guerre froide…")
    ],
    appareils: Annotated[
        str,
        Field(description="Appareils joués et nombre de pilotes (ex. 4 F/A-18C et 2 AH-64D). Vide : le modèle demande"),
    ] = "",
    duree: Annotated[str, Field(description="Durée de vol de la séance, briefing exclu (ex. 2 h). Vide : 2 h")] = "",
    genre: Annotated[
        str,
        Field(
            description="Genre de mission : frappe en profondeur, appui feu, SEAD, escorte… Vide : le modèle propose"
        ),
    ] = "",
    opposition: Annotated[
        str,
        Field(
            description="Niveau de l'opposition : Average, Good, High, Excellent ou Random. Vide : le modèle propose"
        ),
    ] = "",
    langue: Annotated[str, Field(description="Langue de la mission et de son briefing : fr ou en. Vide : fr")] = "",
    dossier: Annotated[
        str,
        Field(description="Dossier vide où créer la mission (ex. C:\\VEAF-Missions\\Golan). Vide : le modèle demande"),
    ] = "",
) -> str:
    """Return the request that starts a one-shot mission with objectives (prompt kind ``objective``).

    Args:
        carte: The DCS map (question 1 of the mission prompt).
        appareils: The aircraft played and how many pilots (question 2); blank leaves it to the prompt.
        duree: The flight time of the session (question 3); blank means 2 h.
        genre: The kind of mission (question 4); blank lets the prompt propose.
        opposition: The opposition's skill level (question 5); blank lets the prompt propose.
        langue: ``fr`` or ``en``; blank means ``fr``.
        dossier: The empty folder to build in; blank makes the model ask.

    Returns:
        The French text the client puts in the user's input box.
    """
    answers = (
        _given("Carte", carte)
        + _given("Appareils joués et nombre de pilotes", appareils)
        + _given("Durée de la séance", duree, "2 h")
        + _given("Genre de mission", genre)
        + _given("Niveau de l'opposition", opposition)
    )
    return _request(
        "mission à objectifs, à jouer en une séance",
        "objective",
        langue,
        answers,
        dossier,
        "le mode de slots, le scénario, les objectifs, la menace, la date, l'heure et la météo",
    )


def open_training(
    carte: Annotated[
        str, Field(description="Carte DCS de l'Open Training : Caucase, Syrie, Mariannes, Allemagne guerre froide…")
    ],
    epoque: Annotated[
        str, Field(description="Époque : moderne, Guerre froide (avec l'année) ou WW2. Vide : moderne")
    ] = "",
    gabarit: Annotated[str, Field(description="Gabarit de départ : minimal, standard ou full. Vide : standard")] = "",
    langue: Annotated[str, Field(description="Langue de la mission et de ses textes : fr ou en. Vide : fr")] = "",
    dossier: Annotated[
        str,
        Field(
            description="Dossier vide où créer la mission (ex. C:\\VEAF-Missions\\OT-Syrie). Vide : le modèle demande"
        ),
    ] = "",
) -> str:
    """Return the request that starts a VEAF Open Training on a whole map (prompt kind ``open-training``).

    Args:
        carte: The DCS map (question 1 of the mission prompt).
        epoque: The era (question 2); blank means modern.
        gabarit: The scaffold template (question 3); blank means ``standard``.
        langue: ``fr`` or ``en``; blank means ``fr``.
        dossier: The empty folder to build in; blank makes the model ask.

    Returns:
        The French text the client puts in the user's input box.
    """
    answers = (
        _given("Carte", carte)
        + _given("Époque", epoque, "moderne")
        + _given("Gabarit de départ de la mission", gabarit, "standard")
    )
    return _request(
        "mission Open Training sur une carte entière",
        "open-training",
        langue,
        answers,
        dossier,
        "une mission existante dont s'inspirer, les escortes, la sécurité, les zones et la date de mission selon l'époque",
    )


def campagne_persistante(
    carte: Annotated[str, Field(description="Théâtre DCS de la campagne : Caucase, Syrie, Golfe Persique…")],
    nom: Annotated[str, Field(description="Nom de la campagne, sans espace (ex. Bouclier-de-l-Oronte)")],
    epoque: Annotated[
        str, Field(description="Époque : moderne, Guerre froide (avec l'année) ou WW2. Vide : moderne")
    ] = "",
    camp: Annotated[str, Field(description="Camp des joueurs : bleu ou rouge. Vide : bleu")] = "",
    fichier: Annotated[
        str,
        Field(
            description="Nom de fichier fixe de la mission sur le serveur (ex. Campagne_Oronte). Vide : le modèle propose"
        ),
    ] = "",
    langue: Annotated[str, Field(description="Langue de la campagne et de ses textes : fr ou en. Vide : fr")] = "",
    dossier: Annotated[
        str, Field(description="Dossier de la campagne (ex. C:\\VEAF-Campagnes\\Oronte). Vide : le modèle demande")
    ] = "",
) -> str:
    """Return the request that starts a persistent campaign: zones that change hands, a front that moves.

    Args:
        carte: The DCS theatre (question 1 of the mission prompt).
        nom: The campaign's name (question 2).
        epoque: The era (question 1); blank means modern.
        camp: The players' side (question 2); blank means blue.
        fichier: The mission's fixed file name (question 2); blank lets the prompt propose it.
        langue: ``fr`` or ``en``; blank means ``fr``.
        dossier: The campaign's folder; blank makes the model ask.

    Returns:
        The French text the client puts in the user's input box.
    """
    answers = (
        _given("Théâtre", carte)
        + _given("Époque", epoque, "moderne")
        + _given("Nom de la campagne", nom)
        + _given("Camp des joueurs", camp, "bleu")
        + _given("Nom de fichier fixe de la mission", fichier)
    )
    return _request(
        "campagne persistante : des zones qui changent de camp et un front qui avance tout seul",
        "persistent-campaign",
        langue,
        answers,
        dossier,
        "le front et ses zones (un tableau à valider), les usines et dépôts, les SAM longue portée, l'IA ennemie ; "
        "aucune date ni météo, le serveur les fixe à chaque chargement",
    )


#: The prompts the server registers, in the order a client lists them: the function, the title and the
#: description a client shows.
PROMPTS: tuple[tuple[Any, str, str], ...] = (
    (
        mission_one_shot,
        "Mission one-shot",
        "Une mission à objectifs, à jouer en une séance : carte, appareils, durée, genre, opposition.",
    ),
    (open_training, "Open Training", "Une mission d'entraînement VEAF sur une carte entière : carte, époque, gabarit."),
    (
        campagne_persistante,
        "Campagne persistante",
        "Des missions dynamiques sur un serveur : zones qui changent de camp, front qui avance.",
    ),
)
