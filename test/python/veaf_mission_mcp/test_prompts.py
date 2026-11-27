"""FEAT-MCP-PROMPTS: the MCP server publishes prompts a pilot fills in.

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

#: What a refused `prompts/get` raises through the in-process client: the error, alone or wrapped by the
#: client's task group.
REFUSED = (MCPError, ExceptionGroup)
EXPECTED = {"nouvelle_mission", "ajouter_qra", "ajouter_zone_de_combat", "ajouter_jtac"}
#: Arguments each prompt must require: without them the text would be a sentence with holes.
REQUIRED = {
    "nouvelle_mission": {"nom", "carte"},
    "ajouter_qra": {"mission", "base", "x", "y"},
    "ajouter_zone_de_combat": {"mission", "nom", "x", "y"},
    "ajouter_jtac": {"mission", "x", "y"},
}
#: A complete set of arguments for each prompt, as Cherry sends them: strings.
FILLED: dict[str, dict[str, str]] = {
    "nouvelle_mission": {"nom": "Marteau-du-Golan", "carte": "Syrie"},
    "ajouter_qra": {"mission": "C:\\VEAF-Missions\\M", "base": "Mezzeh", "x": "-185000", "y": "20000"},
    "ajouter_zone_de_combat": {"mission": "C:\\VEAF-Missions\\M", "nom": "SA6Sasa", "x": "-188500", "y": "12500"},
    "ajouter_jtac": {"mission": "C:\\VEAF-Missions\\M", "x": "-206900", "y": "-16700"},
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

    assert {p.name for p in prompts} == EXPECTED
    assert all(p.description for p in prompts)


def test_every_argument_has_a_description_a_pilot_can_read() -> None:
    for prompt in asyncio.run(_list()):
        assert prompt.arguments, prompt.name
        for argument in prompt.arguments:
            assert argument.description, f"{prompt.name}.{argument.name} has no description"
            # Written for a French-speaking pilot: no English word of the usual vocabulary.
            assert not re.search(r"(the|of|name|path|folder|default)", argument.description, re.IGNORECASE), (
                f"{prompt.name}.{argument.name}: {argument.description!r}"
            )


def test_required_arguments_are_flagged_and_the_others_are_optional() -> None:
    for prompt in asyncio.run(_list()):
        required = {a.name for a in prompt.arguments or [] if a.required}
        assert required == REQUIRED[prompt.name], prompt.name


@pytest.mark.parametrize("name", sorted(EXPECTED))
def test_a_missing_required_argument_is_refused(name: str) -> None:
    with pytest.raises(REFUSED):
        get(name, {})


def test_a_text_for_x_that_is_not_a_number_is_refused() -> None:
    with pytest.raises(REFUSED):
        get("ajouter_qra", {**FILLED["ajouter_qra"], "x": "nord"})


def test_new_mission_with_defaults_and_without() -> None:
    bare = get("nouvelle_mission", FILLED["nouvelle_mission"])
    assert "Marteau-du-Golan" in bare
    assert "Syrie" in bare
    assert "C:\\VEAF-Missions\\Marteau-du-Golan" in bare  # the default folder is explicit
    assert "à toi de choisir" in bare  # date, time, weather, scenario left to the model, said so
    assert "une seule fois" in bare
    assert "describe_authoring_guide" in bare

    full = get(
        "nouvelle_mission",
        {
            **FILLED["nouvelle_mission"],
            "date": "16 avril 2024",
            "heure": "15h00",
            "meteo": "vent d'ouest de 12 nœuds",
            "scenario": "Le 1er Corps tient le Golan.",
            "dossier": "D:\\Missions\\Golan",
        },
    )
    assert "16 avril 2024" in full
    assert "15h00" in full
    assert "vent d'ouest de 12 nœuds" in full
    assert "Le 1er Corps tient le Golan." in full
    assert "D:\\Missions\\Golan" in full
    assert "C:\\VEAF-Missions" not in full


def test_blank_optional_arguments_count_as_absent() -> None:
    """Cherry may send an empty string for a field the user left empty."""
    blank = {"date": "", "heure": " ", "meteo": "", "scenario": "", "dossier": ""}
    assert get("nouvelle_mission", {**FILLED["nouvelle_mission"], **blank}) == get(
        "nouvelle_mission", FILLED["nouvelle_mission"]
    )
    blanks = {
        "ajouter_qra": {"rayon_km": "", "appareils": "", "delai_s": " ", "camp": ""},
        "ajouter_zone_de_combat": {"rayon": "", "contenu": "", "camp": ""},
        "ajouter_jtac": {"code_laser": "", "frequence": "", "modulation": "", "nom": "", "lieu": "", "camp": ""},
    }
    for name, empty in blanks.items():
        assert get(name, {**FILLED[name], **empty}) == get(name, FILLED[name]), name


def test_qra_delay_counts_from_the_first_intrusion() -> None:
    text = get("ajouter_qra", {**FILLED["ajouter_qra"], "delai_s": "900", "rayon_km": "30", "appareils": "2 MiG-29S"})

    assert "900" in text
    assert "première intrusion" in text
    assert "pas depuis le début" in text
    assert "30 km" in text
    assert "x -185000" in text
    assert "y 20000" in text
    assert "2 MiG-29S" in text
    assert "Mezzeh" in text


def test_qra_without_a_delay_says_the_scramble_is_immediate() -> None:
    text = get("ajouter_qra", FILLED["ajouter_qra"])

    assert "dès la première intrusion" in text
    assert "pas depuis le début" not in text


def test_combat_zone_carries_its_geometry_and_content() -> None:
    text = get(
        "ajouter_zone_de_combat",
        {
            **FILLED["ajouter_zone_de_combat"],
            "rayon": "1000",
            "contenu": "une batterie SA-6, active au démarrage",
            "camp": "rouge",
        },
    )

    assert "SA6Sasa" in text
    assert "x -188500" in text
    assert "y 12500" in text
    assert "1000 m" in text
    assert "une batterie SA-6, active au démarrage" in text
    assert "create_combat_zone" in text


def test_jtac_carries_laser_code_and_frequency() -> None:
    text = get(
        "ajouter_jtac",
        {
            **FILLED["ajouter_jtac"],
            "code_laser": "1511",
            "frequence": "35,55",
            "modulation": "FM",
            "lieu": "Tel Abu Nada",
        },
    )

    assert "1511" in text
    assert "FM 35.55" in text  # a decimal comma is accepted and written the way the action takes it
    assert "Tel Abu Nada" in text
    assert "JTAC-1" in text
    assert "set_mission_module" in text
    assert "ASSETS" in text


def test_special_characters_pass_through_unchanged() -> None:
    nasty = "Ké\"ro'sène `x` {nom} \\ ça\nligne 2"
    text = get("ajouter_zone_de_combat", {**FILLED["ajouter_zone_de_combat"], "contenu": nasty})

    assert nasty in text
    text = get("nouvelle_mission", {**FILLED["nouvelle_mission"], "nom": "Été-{0}-%s"})
    assert "Été-{0}-%s" in text


def _cited_actions(text: str) -> set[str]:
    """The names between backticks: prompts write only actions that way, parameters in plain words."""
    return set(re.findall(r"`([a-z][a-z0-9_]*)`", text))


@pytest.mark.parametrize("name", sorted(EXPECTED))
def test_every_cited_action_exists_and_the_guide_names_it(name: str) -> None:
    """No prompt promises a tool that is not there, in either profile, nor one the guide never teaches."""
    cited = _cited_actions(get(name, FILLED[name]))
    assert cited, f"{name} cites no action"
    catalogue = {spec.name for spec in server.CATALOG.list_catalog()}
    guide = read_bundled_text("veaf_mission_mcp", "data", "authoring-guide.md")

    assert cited <= catalogue, cited - catalogue
    taught = {
        a for a in cited if f"`{a}`" in guide or a == "describe_authoring_guide"
    }  # the guide is not its own subject
    assert cited <= taught, cited - taught


@pytest.mark.usefixtures("compact")
@pytest.mark.parametrize("name", sorted(EXPECTED))
def test_compact_profile_serves_the_same_prompts(name: str) -> None:
    """The compact profile hides no action a prompt cites: `list_catalog` still lists each of them."""
    listed = {entry["name"] for entry in server.list_catalog()}
    assert EXPECTED == {p.name for p in asyncio.run(_list())}
    assert _cited_actions(get(name, FILLED[name])) <= listed


def test_prompts_are_not_a_resource_or_a_tool() -> None:
    """The lot adds no tool: the compact profile's tool list stays the four it was."""
    tools = {tool.name for tool in asyncio.run(server.mcp.list_tools())}

    assert not tools & EXPECTED
