"""FEAT-MCP-PROMPTS: the MCP server publishes one prompt per kind of mission.

Every test goes through the SDK client (`prompts/list`, `prompts/get`) wired to the real server object,
not through the Python functions: a decorator that stopped registering would pass the functions' own
tests while Cherry Studio showed no prompt at all.
"""

import asyncio
import re
from typing import Any

import pytest
from mcp import Client
from mcp.shared.exceptions import MCPError
from veaf_libs.bundled_data import read_bundled_text
from veaf_mission_mcp import server
from veaf_mission_mcp.oracle import describe_mission_prompt

#: What a refused `prompts/get` raises through the in-process client: the error, alone or wrapped by the
#: client's task group.
REFUSED = (MCPError, ExceptionGroup)
#: Each prompt and the `describe_mission_prompt` kind it must send the model to.
KINDS = {
    "mission_one_shot": "objective",
    "open_training": "open-training",
    "mission_dynamique": "persistent-campaign",
}
#: The fourth prompt has no mission prompt behind it: a campaign of several missions, whose steps the message carries.
CAMPAIGN = "campagne_persistante"
ALL = [*KINDS, CAMPAIGN]
#: Arguments each prompt must require: without them the message would be a sentence with holes.
REQUIRED = {
    "mission_one_shot": {"carte"},
    "open_training": {"carte"},
    "mission_dynamique": {"carte", "nom"},
    CAMPAIGN: {"carte", "nom"},
}
#: A complete set of arguments for each prompt, as Cherry sends them: strings.
FILLED: dict[str, dict[str, str]] = {
    "mission_one_shot": {"carte": "Syrie"},
    "open_training": {"carte": "Caucase"},
    "mission_dynamique": {"carte": "Syrie", "nom": "Bouclier-de-l-Oronte"},
    CAMPAIGN: {"carte": "Caucase", "nom": "Kolkhida"},
}


async def _list() -> list[Any]:
    async with Client(server.mcp) as client:
        return (await client.list_prompts()).prompts


async def _get(name: str, arguments: dict[str, str] | None = None) -> str:
    async with Client(server.mcp) as client:
        result = await client.get_prompt(name, arguments or {})
    assert len(result.messages) == 1
    assert result.messages[0].role == "user"
    content = result.messages[0].content
    assert content.type == "text"
    return str(content.text)


def get(name: str, arguments: dict[str, str] | None = None) -> str:
    return asyncio.run(_get(name, arguments))


def test_the_server_lists_the_four_prompts() -> None:
    prompts = asyncio.run(_list())

    assert [p.name for p in prompts] == ALL
    assert all(p.description and p.title for p in prompts)


def test_every_argument_has_a_description_a_pilot_can_read() -> None:
    for prompt in asyncio.run(_list()):
        assert prompt.arguments, prompt.name
        for argument in prompt.arguments:
            assert argument.description, f"{prompt.name}.{argument.name} has no description"
            # Written for a French-speaking pilot: no English word of the usual vocabulary.
            assert not re.search(r"\b(the|of|name|path|folder|default)\b", argument.description, re.IGNORECASE), (
                f"{prompt.name}.{argument.name}: {argument.description!r}"
            )


def test_required_arguments_are_flagged_and_the_others_are_optional() -> None:
    for prompt in asyncio.run(_list()):
        required = {a.name for a in prompt.arguments or [] if a.required}
        assert required == REQUIRED[prompt.name], prompt.name


def test_every_prompt_takes_the_language_and_the_folder() -> None:
    """The two answers every kind of mission needs, offered by all three."""
    for prompt in asyncio.run(_list()):
        assert {"langue", "dossier"} <= {a.name for a in prompt.arguments or []}, prompt.name


@pytest.mark.parametrize("name", ALL)
def test_a_missing_required_argument_is_refused(name: str) -> None:
    with pytest.raises(REFUSED):
        get(name, {})


@pytest.mark.parametrize("name", ALL)
def test_a_language_other_than_fr_or_en_is_refused(name: str) -> None:
    with pytest.raises(REFUSED):
        get(name, {**FILLED[name], "langue": "de"})


@pytest.mark.parametrize("name", sorted(KINDS))
def test_the_message_sends_the_model_to_the_prompt_of_its_kind(name: str) -> None:
    text = get(name, FILLED[name])

    assert "`describe_mission_prompt`" in text
    assert f'kind : "{KINDS[name]}"' in text
    assert 'lang : "fr"' in text  # French by default
    assert "`describe_authoring_guide`" in text
    assert "ne me les repose pas" in text
    assert "demande-moi où le créer" in text  # no folder given: the model asks, nothing is invented


@pytest.mark.parametrize("name", sorted(KINDS))
def test_the_message_is_short_and_does_not_copy_the_mission_prompt(name: str) -> None:
    """The guide and the mission prompts stay the single source: the message only points at them."""
    text = get(name, FILLED[name])
    full = describe_mission_prompt(KINDS[name], "fr", part="all")["prompt"]

    assert len(text) < 1_500
    assert len(full) > 5_000, "the prompt this message points at is the real one"
    assert next(line for line in full.splitlines() if line.strip()) not in text


@pytest.mark.parametrize("name", sorted(KINDS))
def test_each_kind_loads_through_describe_mission_prompt_in_both_languages(name: str) -> None:
    """What the message tells the model to ask for exists, in each language it can name."""
    for lang in ("fr", "en"):
        assert describe_mission_prompt(KINDS[name], lang)["prompt"], (name, lang)


def test_one_shot_carries_its_answers_and_its_defaults() -> None:
    bare = get("mission_one_shot", FILLED["mission_one_shot"])
    assert "Carte : Syrie" in bare
    assert "Durée de la séance : 2 h" in bare  # the prompt's own recommendation
    assert "Appareils joués" not in bare
    assert "Genre de mission" not in bare
    assert "Niveau de l'opposition" not in bare

    full = get(
        "mission_one_shot",
        {
            **FILLED["mission_one_shot"],
            "appareils": "4 F/A-18C et 2 AH-64D",
            "duree": "3 h",
            "genre": "SEAD",
            "opposition": "High",
            "langue": "EN",
            "dossier": "D:\\Missions\\Golan",
        },
    )
    assert "4 F/A-18C et 2 AH-64D" in full
    assert "Durée de la séance : 3 h" in full
    assert "Genre de mission : SEAD" in full
    assert "Niveau de l'opposition : High" in full
    assert 'lang : "en"' in full  # any case, written the way the action takes it
    assert "Dossier de la mission : D:\\Missions\\Golan" in full
    assert "demande-moi" not in full
    assert "la date, l'heure et la météo" in full  # what the prompt proposes itself, not asked here


def test_open_training_defaults_to_modern_and_standard() -> None:
    text = get("open_training", FILLED["open_training"])

    assert "Époque : moderne" in text
    assert "Gabarit de départ de la mission : standard" in text
    assert "une mission existante dont s'inspirer" in text  # stays with the prompt


def test_dynamic_mission_fixes_no_date_and_keeps_the_front_for_the_prompt() -> None:
    text = get(
        "mission_dynamique",
        {**FILLED["mission_dynamique"], "camp": "rouge", "fichier": "Campagne_Oronte", "epoque": "WW2"},
    )

    assert "Nom de la mission : Bouclier-de-l-Oronte" in text
    assert "Camp des joueurs : rouge" in text
    assert "Nom de fichier fixe de la mission : Campagne_Oronte" in text
    assert "Époque : WW2" in text
    assert "à la Foothold" in text
    assert "aucune date ni météo" in text
    assert "un tableau à valider" in text
    assert "Camp des joueurs : bleu" in get("mission_dynamique", FILLED["mission_dynamique"])


def test_persistent_campaign_walks_the_model_through_the_campaign_actions() -> None:
    """Several missions, one per evening: no mission prompt exists for it, the message carries the sequence."""
    text = get(CAMPAIGN, {**FILLED[CAMPAIGN], "histoire": "La Géorgie contre la Russie", "camp": "rouge"})

    assert "plusieurs missions jouées soir après soir" in text
    assert "Théâtre : Caucase" in text
    assert "Nom de la campagne : Kolkhida" in text
    assert "Camp des joueurs : rouge" in text
    assert "Fil de la campagne : La Géorgie contre la Russie" in text
    assert "`campaign_init`" in text
    assert '"multi-mission"' in text
    assert "`campaign_validate`" in text
    assert "`campaign_next`" in text
    assert "pas de mission 2 avant" in text
    assert "describe_mission_prompt" not in text  # not the persistent-campaign mission prompt
    assert "demande-moi où le créer" in text
    assert len(text) < 1_800


def test_the_campaign_actions_the_message_names_take_the_example_it_gives() -> None:
    """`campaign_init` really offers the "multi-mission" example the message tells the model to pass."""
    spec = server.CATALOG.describe_action("campaign_init")

    assert "multi-mission" in spec.parameters_schema["properties"]["example"]["enum"]


def test_blank_optional_arguments_count_as_absent() -> None:
    """Cherry may send an empty string for a field the user left empty."""
    blanks = {
        "mission_one_shot": {"appareils": "", "duree": " ", "genre": "", "opposition": "", "langue": "", "dossier": ""},
        "open_training": {"epoque": "", "gabarit": " ", "langue": "", "dossier": ""},
        "mission_dynamique": {"epoque": "", "camp": "", "fichier": " ", "langue": "", "dossier": ""},
        CAMPAIGN: {"epoque": "", "camp": "", "histoire": " ", "langue": "", "dossier": ""},
    }
    for name, empty in blanks.items():
        assert get(name, {**FILLED[name], **empty}) == get(name, FILLED[name]), name


def test_special_characters_pass_through_unchanged() -> None:
    nasty = "Ké\"ro'sène `x` {nom} \\ ça\nligne 2"
    text = get(CAMPAIGN, {**FILLED[CAMPAIGN], "nom": nasty})

    assert nasty in text
    text = get("mission_one_shot", {**FILLED["mission_one_shot"], "genre": "Été-{0}-%s"})
    assert "Été-{0}-%s" in text


def _cited_actions(text: str) -> set[str]:
    """The names between backticks: prompts write only actions that way, parameters in plain words."""
    return set(re.findall(r"`([a-z][a-z0-9_]*)`", text))


#: Actions the guide does not name, only the multi-mission campaign's message does: no mission prompt holds it.
NOT_IN_THE_GUIDE = {"campaign_init", "campaign_validate"}


@pytest.mark.parametrize("name", ALL)
def test_every_cited_action_exists_and_the_guide_names_it(name: str) -> None:
    """No prompt promises a tool that is not there, in either profile, nor one the guide never teaches."""
    cited = _cited_actions(get(name, FILLED[name]))
    assert cited, f"{name} cites no action"
    catalogue = {spec.name for spec in server.CATALOG.list_catalog()}
    guide = read_bundled_text("veaf_mission_mcp", "data", "authoring-guide.md")

    assert cited <= catalogue, cited - catalogue
    # The guide is not its own subject; the campaign's two actions are in their catalogue descriptions.
    taught = {a for a in cited if f"`{a}`" in guide or a == "describe_authoring_guide" or a in NOT_IN_THE_GUIDE}
    assert cited <= taught, cited - taught


@pytest.mark.usefixtures("compact")
@pytest.mark.parametrize("name", ALL)
def test_compact_profile_serves_the_same_prompts(name: str) -> None:
    """The compact profile hides no action a prompt cites: `list_catalog` still lists each of them."""
    listed = {entry["name"] for entry in server.list_catalog()}
    assert set(ALL) == {p.name for p in asyncio.run(_list())}
    assert _cited_actions(get(name, FILLED[name])) <= listed


def test_prompts_are_not_a_resource_or_a_tool() -> None:
    """The lot adds no tool: the prompts are not among the server's tools."""
    tools = {tool.name for tool in asyncio.run(server.mcp.list_tools())}

    assert not tools & set(ALL)
