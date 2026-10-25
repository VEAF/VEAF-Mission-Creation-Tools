"""Tests for the wave-5 domain-knowledge oracle (introspection actions)."""

import json
from pathlib import Path

import pytest
from veaf_mission_mcp.oracle import (
    _command_category,
    describe_authoring_guide,
    describe_known_limitations,
    describe_mission_prompt,
    describe_module,
    describe_naming_conventions,
    list_payloads,
    list_shortcuts,
    list_unit_types,
)


def test_list_unit_types_returns_dcs_units_from_canonical_data() -> None:
    units = list_unit_types()["units"]
    assert units, "expected a non-empty DCS unit list from the bundled dcsUnits.yaml"
    sample = units[0]
    assert sample["type"] and "category" in sample


def test_list_unit_types_filters_by_category() -> None:
    all_units = list_unit_types()["units"]
    category = all_units[0]["category"]
    filtered = list_unit_types(category=category)["units"]
    assert filtered
    assert all(u["category"] == category for u in filtered)


def test_list_unit_types_filters_by_name_substring() -> None:
    all_units = list_unit_types()["units"]
    needle = all_units[0]["type"][:3].lower()
    filtered = list_unit_types(name_contains=needle)["units"]
    assert filtered
    assert all(needle in (u["type"] + u["name"]).lower() for u in filtered)


def test_list_shortcuts_includes_known_unit_alias() -> None:
    shortcuts = list_shortcuts()
    assert any("shilka" in entry["aliases"] for entry in shortcuts["units"])


def test_list_shortcuts_includes_composite_groups() -> None:
    assert list_shortcuts()["groups"], "expected composite spawn groups from veaf-units.yaml"


def test_list_shortcuts_filters_by_substring() -> None:
    filtered = list_shortcuts(name_contains="shilka")
    assert any("shilka" in e["aliases"] for e in filtered["units"])
    assert all(
        "shilka" in " ".join(e["aliases"]).lower() or "shilka" in e["unitType"].lower() for e in filtered["units"]
    )


def test_list_shortcuts_includes_command_aliases() -> None:
    # The #command shortcuts from veafShortcuts.buildDefaultList() (regression: the LLM
    # invented `-lrsam` because the real `-samLR` was invisible to the oracle).
    names = [alias for entry in list_shortcuts()["commands"] for alias in entry["aliases"]]
    assert "-samLR" in names
    assert "-samSR" in names


def test_list_shortcuts_commands_filtered_by_substring() -> None:
    filtered = list_shortcuts(name_contains="samLR")
    names = [alias for entry in filtered["commands"] for alias in entry["aliases"]]
    assert "-samLR" in names
    assert "-samSR" not in names  # filtered out


def test_list_shortcuts_command_entries_have_shape() -> None:
    commands = list_shortcuts()["commands"]
    assert commands
    entry = commands[0]
    assert "aliases" in entry and "description" in entry and "veafCommand" in entry


def test_list_shortcuts_commands_carry_their_random_parameters() -> None:
    """`-samLR` and `-samSR` share one command: only the `defense` range drawn on each use differs."""
    by_name = {entry["aliases"][0]: entry for entry in list_shortcuts()["commands"]}
    assert by_name["-samLR"]["randomParameters"]["defense"] == {"min": 4, "max": 5}
    assert by_name["-samSR"]["randomParameters"]["defense"] == {"min": 2, "max": 3}


def test_describe_known_limitations_returns_both_kinds_for_the_running_version() -> None:
    result = describe_known_limitations(full=True)
    assert result["veaf_tools_version"]
    kinds = {entry["kind"] for entry in result["limitations"]}
    assert kinds == {"dcs", "tool"}
    entry = result["limitations"][0]
    assert {"id", "kind", "area", "title", "symptom", "workaround"} <= set(entry)


class TestKnownLimitationsByArea:
    """FIX-OPEN-TRAINING-NORMANDY-FINDINGS 10: the whole text, 74 000 characters, overflowed a tool result."""

    def test_the_default_is_a_short_listing_that_fits_a_tool_result(self) -> None:
        result = describe_known_limitations()
        assert result["detail"] == "short"
        assert {"id", "kind", "area"} <= set(result["limitations"][0])
        # No title since FIX-LIMITATIONS-SHORT-LISTING: with them the listing reached 14 988 of its 15 000
        # characters; the ids already say what an entry is about.
        assert all(set(entry) <= {"id", "kind", "area", "theatres"} for entry in result["limitations"])
        assert len(json.dumps(result, ensure_ascii=False)) < 15_000
        assert sum(result["areas"].values()) == len(result["limitations"])

    def test_the_short_listing_names_every_entry_of_the_full_text(self) -> None:
        short = {entry["id"] for entry in describe_known_limitations()["limitations"]}
        assert short == {entry["id"] for entry in describe_known_limitations(full=True)["limitations"]}

    def test_an_area_returns_its_entries_short(self) -> None:
        """Three areas in full were 46k characters in one call (FIX-OPENCODE-TEST-FINDINGS 06)."""
        result = describe_known_limitations(area="radio")
        assert result["detail"] == "short"
        assert result["limitations"] and {e["area"] for e in result["limitations"]} == {"radio"}
        assert all("symptom" not in entry for entry in result["limitations"])

    def test_an_area_in_full_on_request(self) -> None:
        result = describe_known_limitations(area="radio", full=True)
        assert result["detail"] == "full"
        assert all("symptom" in entry and "workaround" in entry for entry in result["limitations"])

    def test_the_three_largest_areas_read_short_stay_small(self) -> None:
        areas = describe_known_limitations()["areas"]
        largest = sorted(areas, key=areas.get, reverse=True)[:3]
        size = sum(len(json.dumps(describe_known_limitations(area=a), indent=2)) for a in largest)
        assert size < 8_000

    def test_one_or_several_ids_return_those_entries_in_full(self) -> None:
        first, second = (e["id"] for e in describe_known_limitations()["limitations"][:2])
        assert [e["id"] for e in describe_known_limitations(id=first)["limitations"]] == [first]
        assert {e["id"] for e in describe_known_limitations(id=[first, second])["limitations"]} == {first, second}

    def test_an_unknown_id_is_refused(self) -> None:
        with pytest.raises(ValueError, match="no known limitation"):
            describe_known_limitations(id="no-such-limitation")

    def test_a_theatre_drops_the_entries_that_concern_other_theatres_only(self) -> None:
        ids = {e["id"] for e in describe_known_limitations(theatre="Normandy")["limitations"]}
        assert "ai-ground-start-needs-a-parking-capture" not in ids  # Normandy ships its parking
        assert "marianas-placement-checks-nothing" not in ids
        everywhere = {e["id"] for e in describe_known_limitations()["limitations"]}
        assert "ai-ground-start-needs-a-parking-capture" in {
            e["id"] for e in describe_known_limitations(theatre="Nevada")["limitations"]
        }
        assert ids < everywhere  # an entry with no `theatres` is kept


def test_describe_known_limitations_filters_by_kind() -> None:
    assert {e["kind"] for e in describe_known_limitations(kind="dcs")["limitations"]} == {"dcs"}


def test_describe_known_limitations_is_in_the_catalogue() -> None:
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog

    catalog = ActionCatalog()
    register_default_actions(catalog)
    assert "describe_known_limitations" in {spec.name for spec in catalog.list_catalog()}
    assert catalog.run_action("describe_known_limitations", {"kind": "tool"})["limitations"]


_MCP_DATA = Path(__file__).parents[3] / "src" / "python" / "veaf-tools" / "veaf_mission_mcp" / "data"


def test_describe_authoring_guide_returns_the_package_guide_verbatim() -> None:
    """FEAT-AI-ZERO-SETUP: the guide lives in the package it is served from, one copy."""
    guide = _MCP_DATA / "authoring-guide.md"
    assert describe_authoring_guide() == {"guide": guide.read_text(encoding="utf-8")}


def test_describe_authoring_guide_reads_the_bundled_copy_in_the_executable(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """In the exe, the copy the build bundles is the one read."""
    bundled = tmp_path / "veaf_mission_mcp" / "data" / "authoring-guide.md"
    bundled.parent.mkdir(parents=True)
    bundled.write_text("bundled guide", encoding="utf-8")
    monkeypatch.setattr("sys._MEIPASS", str(tmp_path), raising=False)
    assert describe_authoring_guide() == {"guide": "bundled guide"}


def test_describe_authoring_guide_is_in_the_catalogue() -> None:
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog

    catalog = ActionCatalog()
    register_default_actions(catalog)
    assert "Authoring VEAF missions" in catalog.run_action("describe_authoring_guide", {})["guide"]


def test_the_authoring_guide_sends_a_mission_request_to_the_mission_prompts() -> None:
    """A user who only says "create a mission" must reach the prompts without naming them."""
    guide = describe_authoring_guide()["guide"]
    assert "describe_mission_prompt" in guide
    assert "objective" in guide and "open-training" in guide


@pytest.mark.parametrize("kind", ["objective", "open-training"])
@pytest.mark.parametrize("lang", ["fr", "en"])
def test_describe_mission_prompt_returns_each_shipped_prompt(kind: str, lang: str) -> None:
    expected = (_MCP_DATA / "mission-prompts" / f"new-{kind}-mission.{lang}.md").read_text(encoding="utf-8")
    assert describe_mission_prompt(kind, lang, part="all") == {"kind": kind, "lang": lang, "prompt": expected}


class TestMissionPromptParts:
    """FIX-OPENCODE-TEST-FINDINGS 06: sections 4-9 of the objective prompt, 21k of its 34k, serve only after approval.

    Read up front, they were carried through every turn of the scenario discussion.
    """

    @pytest.mark.parametrize("lang", ["fr", "en"])
    def test_the_objective_prompt_starts_with_the_scenario_part(self, lang: str) -> None:
        result = describe_mission_prompt("objective", lang)
        assert result["part"] == "scenario" and result["next_part"] == "build"
        assert "## 2." in result["prompt"] and "## 4." not in result["prompt"]
        assert "part: build" in result["prompt"], "the scenario part says how to load the rest"
        assert len(result["prompt"]) < 15_000

    @pytest.mark.parametrize("lang", ["fr", "en"])
    def test_the_build_part_is_the_rest(self, lang: str) -> None:
        whole = describe_mission_prompt("objective", lang, part="all")["prompt"]
        scenario = describe_mission_prompt("objective", lang)["prompt"]
        build = describe_mission_prompt("objective", lang, part="build")
        assert build["prompt"].startswith("## 4.")
        assert scenario + "<!-- part: build -->\n" + build["prompt"] == whole

    def test_a_prompt_with_no_parts_comes_whole(self) -> None:
        result = describe_mission_prompt("open-training", "en")
        assert "part" not in result and "## 8." in result["prompt"]

    def test_an_unknown_part_is_refused(self) -> None:
        with pytest.raises(ValueError, match="part"):
            describe_mission_prompt("objective", "en", part="epilogue")


def test_describe_mission_prompt_defaults_to_english() -> None:
    assert describe_mission_prompt("objective")["lang"] == "en"


def test_describe_mission_prompt_refuses_an_unknown_kind() -> None:
    with pytest.raises(ValueError, match="objective, open-training"):
        describe_mission_prompt("campaign", "en")


def test_describe_mission_prompt_reads_the_bundled_copy_in_the_executable(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bundled = tmp_path / "veaf_mission_mcp" / "data" / "mission-prompts" / "new-objective-mission.fr.md"
    bundled.parent.mkdir(parents=True)
    bundled.write_text("prompt embarqué", encoding="utf-8")
    monkeypatch.setattr("sys._MEIPASS", str(tmp_path), raising=False)
    assert describe_mission_prompt("objective", "fr")["prompt"] == "prompt embarqué"


def test_describe_mission_prompt_is_in_the_catalogue() -> None:
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog

    catalog = ActionCatalog()
    register_default_actions(catalog)
    result = catalog.run_action("describe_mission_prompt", {"kind": "open-training", "lang": "fr"})
    assert result["prompt"].startswith("# Prompt — construire une mission VEAF Open Training")


def test_describe_naming_conventions_lists_the_reserved_patterns() -> None:
    conventions = describe_naming_conventions()["conventions"]
    assert len(conventions) >= 8
    ids = {c["id"] for c in conventions}
    assert "combat_zone_membership" in ids
    assert "spawn_template" in ids
    for convention in conventions:
        assert convention["rule"] and convention["module"]


def test_describe_module_known_returns_doc_page() -> None:
    result = describe_module("QRA")
    assert result["known"] is True
    assert result["doc_page"].endswith(".md")


def test_describe_module_is_case_insensitive() -> None:
    assert describe_module("qra")["known"] is True


def test_describe_module_unknown() -> None:
    assert describe_module("NOSUCHMODULE")["known"] is False


def test_describe_module_reports_enabled_from_mission_yaml(tmp_path: Path) -> None:
    path = tmp_path / "mission.yaml"
    path.write_text("modules:\n  QRA: true\n  COMBATZONE: false\n", encoding="utf-8")
    assert describe_module("QRA", mission_yaml_path=path)["enabled"] is True
    assert describe_module("COMBATZONE", mission_yaml_path=path)["enabled"] is False


def test_command_category_classifies_known_families() -> None:
    assert _command_category(["-samLR"], "Random long range SAM battery") == "SAM"
    assert _command_category(["-aaa"], "Random AAA battery") == "AAA"
    assert _command_category(["-infantry"], "Dynamic infantry section") == "infantry"
    assert _command_category(["-armor"], "Random armor group") == "armor"
    assert _command_category(["-mortar"], "Mortar artillery team") == "artillery"


def test_command_category_falls_back_to_other() -> None:
    assert _command_category(["-zzz"], "something with no known family") == "other"


def test_list_shortcuts_commands_carry_a_category() -> None:
    commands = list_shortcuts()["commands"]
    assert commands, "expected a non-empty command alias list"
    assert all("category" in c for c in commands)


def test_list_unit_types_gives_the_ranges_where_dcs_has_one() -> None:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 08: the Syria mission read them from a DCS dump by hand."""
    units = {u["type"]: u for u in list_unit_types(name_contains="Patriot")["units"]}
    assert units["Patriot ln"]["threat_range_m"] == 100000
    assert units["Patriot str"]["detection_range_m"] == 160000
    assert "threat_range_m" not in units["Patriot str"]


class TestListPayloads:
    """FIX-OPEN-TRAINING-SYRIA-FINDINGS 09: the loadouts the Mission Editor offers, by name."""

    def test_a_type_lists_its_loadouts_with_their_pylons(self) -> None:
        answer = list_payloads("MiG-31")
        by_name = {p["name"]: p["pylons"] for p in answer["payloads"]}
        assert by_name["R-40T*2,R-33*4"][1] == "{5F26DBC2-FB43-4153-92DE-6BBCE26CB0FF}"

    def test_without_a_type_it_lists_the_types(self) -> None:
        types = list_payloads()["types"]
        assert {"MiG-29S", "Su-27", "Su-30", "MiG-31", "Su-24M", "Tu-22M3", "F-15E"} <= set(types)

    def test_a_type_without_loadouts_is_refused_naming_those_that_have_some(self) -> None:
        with pytest.raises(ValueError, match="MiG-31"):
            list_payloads("SpitfireLFMkIX")  # no loadout file in the install, module or not


def test_the_action_takes_one_id_or_a_list_of_ids_without_a_oneof_schema() -> None:
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog

    catalog = ActionCatalog()
    register_default_actions(catalog)
    first, second = (e["id"] for e in describe_known_limitations()["limitations"][:2])
    assert [e["id"] for e in catalog.run_action("describe_known_limitations", {"id": first})["limitations"]] == [first]
    both = catalog.run_action("describe_known_limitations", {"ids": [first, second]})["limitations"]
    assert {e["id"] for e in both} == {first, second}
    spec = next(s for s in catalog.list_catalog() if s.name == "describe_known_limitations")
    assert "oneOf" not in json.dumps(spec.parameters_schema)


def test_the_guide_has_every_new_mission_adapt_the_scaffold_first() -> None:
    """A 6.30.0 test mission kept the scaffold's presets, date, waypoints, warbirds and SKYNET: false.

    The checklist was in the guide, deep under a section written for an Open Training; it now comes
    right after the routing and names each file, Skynet included (FEAT-AI-ZERO-SETUP).
    """
    guide = describe_authoring_guide()["guide"]
    section = guide.index("## Right after `scaffold_mission` — every new mission")
    assert section < guide.index("## Always ground yourself in the oracle")
    checklist = guide[section : guide.index("## Always ground yourself in the oracle")]
    for item in ("presets.yaml", "versions.yaml", "waypoints.yaml", "dynamic-slot-templates.yaml", "SKYNET"):
        assert item in checklist, item


@pytest.mark.parametrize("kind", ["objective", "open-training"])
@pytest.mark.parametrize("lang", ["fr", "en"])
def test_a_mission_prompt_names_no_skill_that_does_not_ship(kind: str, lang: str) -> None:
    """The plugin and its skill are gone: a prompt asking to load it sends the assistant nowhere."""
    prompt = describe_mission_prompt(kind, lang)["prompt"]
    assert "veaf-mission-editor:" not in prompt
    assert "describe_authoring_guide" in prompt


def test_the_parking_limitation_says_dynamic_slots_are_not_concerned() -> None:
    """FIX-MISSION-LANGUAGE-FOLLOWS-USER 02: listed by its id alone, `no-parking-data-outside-three-theatres`
    made an AI tell the user GermanyCW had "no parking places for the dynamic slots" — DCS places those
    players itself; the capture only serves the ground and runway starts of the flights the tools place.
    """
    entry = describe_known_limitations(id="ai-ground-start-needs-a-parking-capture")["limitations"][0]
    assert "dynamic slots" in entry["title"].lower()


@pytest.mark.parametrize("kind", ["objective", "open-training"])
def test_an_english_prompt_builds_an_english_mission(kind: str) -> None:
    """FIX-MISSION-LANGUAGE-FOLLOWS-USER: the English prompts told the assistant to write the mission, its
    briefing and its README in French, and an English-speaking user got a French mission.
    """
    prompt = describe_mission_prompt(kind, "en", part="all")["prompt"]
    assert "mission.language: fr" not in prompt
    assert "in French" not in prompt
    assert "mission.language: en" in prompt


class TestListCountries:
    """FIX-OPENCODE-TEST-FINDINGS 03: the AI read dcs-countries.yaml out of the exe's unpacked files."""

    def test_finds_a_country_by_name_or_short_code(self) -> None:
        from veaf_mission_mcp.oracle import list_countries

        turkey = list_countries(name_contains="turk")["countries"]
        assert [(c["id"], c["name"]) for c in turkey] == [(3, "Turkey")]
        assert any(c["name"] == "USA" for c in list_countries(name_contains="usa")["countries"])

    def test_lists_them_all_in_id_order(self) -> None:
        from veaf_mission_mcp.oracle import list_countries

        ids = [c["id"] for c in list_countries()["countries"]]
        assert ids == sorted(ids) and len(ids) > 80

    def test_the_action_is_in_the_catalogue(self) -> None:
        from veaf_mission_mcp.server import CATALOG

        assert CATALOG.run_action("list_countries", {"name_contains": "syria"})["countries"][0]["name"] == "Syria"


class TestNoShellParsing:
    """FIX-OPENCODE-TEST-FINDINGS 08: "open the built .miz and check" sent the AI to unzip it in PowerShell."""

    def test_the_guide_forbids_reading_a_mission_through_a_shell(self) -> None:
        guide = describe_authoring_guide()["guide"]
        assert "never through a shell" in guide
        assert "inspect_built_mission" in guide

    @pytest.mark.parametrize(
        "name",
        [
            "authoring-guide.md",
            "mission-prompts/new-objective-mission.en.md",
            "mission-prompts/new-objective-mission.fr.md",
            "mission-prompts/new-open-training-mission.en.md",
            "mission-prompts/new-open-training-mission.fr.md",
        ],
    )
    def test_nothing_asks_to_open_a_miz_by_hand(self, name: str) -> None:
        text = (_MCP_DATA / name).read_text(encoding="utf-8").lower()
        for phrase in ("open the built `.miz`", "open the produced `.miz`", "ouvre le `.miz`", "veaf_libs/data/"):
            assert phrase not in text, phrase
        assert "inspect_built_mission" in text


@pytest.mark.parametrize(
    ("lang", "doctrine", "level"),
    [
        ("en", "Flown as the aircraft is flown", "The level of the opposition"),
        ("fr", "Volé comme l'appareil se vole", "Le niveau de l'opposition"),
    ],
)
def test_the_objective_prompt_plans_the_route_and_asks_the_level(lang: str, doctrine: str, level: str) -> None:
    """FIX-COWORK-SESSION-FINDINGS 09 and 10: the route designed after the aircraft, two candidates measured."""
    scenario = describe_mission_prompt("objective", lang)["prompt"]
    assert doctrine in scenario and level in scenario
    assert "**two**" in scenario or "**deux**" in scenario
    build = describe_mission_prompt("objective", lang, part="build")["prompt"]
    assert "set_route" in build and "`basemap: topo`" in build and "password-hash" in build
