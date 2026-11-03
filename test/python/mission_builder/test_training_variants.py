"""Tests for the training versions of a mission night (FEAT-ROLE-TRAINING-VARIANTS).

The fixture is a small night: an enemy CAP flight, a QRA, an on-demand CAP, a long-range SAM, a combat
zone with its target, the SA-6 that protects it and two SA-8 the briefing only calls "defences around",
a column of tanks described as vague, and a blue group nobody declares. **No VEAF command at all**: the
draws must work on a mission whose units are all placed by hand.
"""

from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest
from mission_builder.group_removal import group_names, remove_groups
from mission_builder.training_variants import (
    ROLES,
    TrainingError,
    apply_to_mission,
    check_training,
    parse_training,
    plan_variant,
    reference_sources,
    variant_profiles,
    with_training_profiles,
)
from training_fixtures import group as _group
from training_fixtures import night_mission as _mission
from training_fixtures import night_training as _training
from training_fixtures import night_yaml as _yaml
from training_fixtures import unit as _unit


def _build(role: str, yaml_data: dict[str, Any] | None = None, references: list | None = None) -> tuple:
    """Plan a version, apply it to a copy of the mission, return ``(variant, mission)``."""
    mission = _mission()
    variant = plan_variant(role, yaml_data or _yaml(), mission, references)
    built = copy.deepcopy(mission)
    apply_to_mission(built, variant)
    return variant, built


def _units(mission: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Every unit by name."""
    found = {}
    for coalition in mission["coalition"].values():
        for country in coalition["country"]:
            for category in ("plane", "vehicle", "static"):
                for group in (country.get(category) or {}).get("group", []):
                    for unit in group["units"]:
                        found[unit["name"]] = unit
    return found


# ── group_removal ──────────────────────────────────────────────────────────────────────────────


class TestRemoveGroups:
    def test_an_exact_name_with_brackets_matches_itself(self) -> None:
        """`[...]` is a character class to fnmatch: an interpreter static's own name did not match it."""
        mission = _mission()
        name = '#veafInterpreter["-samVLR"] #gudauta'
        mission["coalition"]["red"]["country"][0]["static"] = {"group": [_group(name, [_unit(name, "Cargo1", 0, 0)])]}
        removed, unmatched = remove_groups(mission, [name])
        assert (removed, unmatched) == ([name], [])

    def test_removes_by_exact_name_and_pattern(self) -> None:
        mission = _mission()
        removed, unmatched = remove_groups(mission, ["Blue HQ", "Factory-SA-8 *", "Nothing*"])
        assert removed == ["Factory-SA-8 #1", "Factory-SA-8 #2", "Blue HQ"]
        assert unmatched == ["Nothing*"]
        names = group_names(mission)
        assert "Blue HQ" not in names and "Factory-SA-6" in names

    def test_an_emptied_container_is_dropped(self) -> None:
        mission = _mission()
        remove_groups(mission, ["Blue HQ"])
        assert "vehicle" not in mission["coalition"]["blue"]["country"][0]

    def test_a_container_it_does_not_touch_stays_identical(self) -> None:
        mission = _mission()
        before = copy.deepcopy(mission)
        removed, _ = remove_groups(mission, ["Nothing"])
        assert removed == [] and mission == before

    def test_matching_is_case_sensitive_as_dcs_names_are(self) -> None:
        mission = _mission()
        removed, unmatched = remove_groups(mission, ["blue hq"])
        assert removed == [] and unmatched == ["blue hq"]


# ── parsing ────────────────────────────────────────────────────────────────────────────────────


class TestParse:
    def test_the_fixture_parses(self) -> None:
        plan, errors = parse_training(_training())
        assert errors == []
        assert plan is not None and len(plan.elements) == 6 and len(plan.draws) == 2
        assert plan.draws[0].count == "1-2" and plan.draws[1].count == "1"

    def test_absent_block(self) -> None:
        assert parse_training(None) == (None, [])

    @pytest.mark.parametrize(
        ("raw", "fragment"),
        [
            ("nope", "must be a mapping"),
            ({"elements": [{"groups": ["x"], "kind": "tanker"}]}, "unknown kind 'tanker'"),
            ({"elements": [{"kind": "qra"}]}, "exactly one of"),
            ({"elements": [{"qra": "a", "zone": "b", "kind": "qra"}]}, "exactly one of"),
            ({"elements": [{"groups": [], "kind": "qra"}]}, "'groups' must be"),
            ({"elsewhere": []}, "unknown key 'elsewhere'"),
            ({"randomize": [{"name": "a b", "replaces": "x", "pool": [{"group": "x"}]}]}, "'name' must be"),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": []}]}, "'pool' must list"),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "count": "2-1"}]}, "range"),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "radius": "far"}]}, "range"),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "count": 2}]}, "pool of 1"),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x", "command": "-sa8"}]}]}, "one of"),
            (
                {"randomize": [{"name": "a", "replaces": "x", "pool": [{"units": [{"type": "T-72B", "count": 0}]}]}]},
                "units",
            ),
            ({"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "at": {"x": 1}}]}, "'at'"),
            (
                {
                    "randomize": [
                        {"name": "a", "replaces": "x", "pool": [{"group": "x"}]},
                        {"name": "A", "replaces": "y", "pool": [{"group": "y"}]},
                    ]
                },
                "already used",
            ),
        ],
    )
    def test_malformed_blocks_are_refused_with_a_reason(self, raw: object, fragment: str) -> None:
        plan, errors = parse_training(raw)
        assert plan is None
        assert any(fragment in error for error in errors), errors


# ── the rule table ─────────────────────────────────────────────────────────────────────────────

#: Group → the roles whose version keeps it.
_KEPT = {
    "Red CAP Maykop": {"CAP", "ALL"},
    "SA-10 Gudauta": {"CAP", "SEAD", "ALL"},
    "Factory-Tanks": {"A2G", "ALL"},
    "Factory-SA-6": set(ROLES),
    "Factory-Shilka": {"A2G", "CAP", "ALL"},  # air defence nobody declared: CAP keeps every SAM, SEAD only the declared
    "Blue HQ": set(ROLES),
    "QRA-Maykop-MiG29": set(ROLES),  # a QRA is taken out by its definition, its late-activated group stays
    "Factory-SA-8 #1": set(ROLES),  # adopted by its draw, same name: its zone is Factory
    "Factory-SA-8 #2": set(),  # replaced by the draw and not in its pool
    "Column 2": set(),
}


@pytest.mark.parametrize("role", ROLES)
@pytest.mark.parametrize("group", sorted(_KEPT))
def test_every_group_of_the_rule_table(role: str, group: str) -> None:
    _, built = _build(role)
    assert (group in group_names(built)) == (role in _KEPT[group])


@pytest.mark.parametrize("role", ROLES)
def test_the_qra_definition_by_role(role: str) -> None:
    variant, _ = _build(role)
    definitions = variant.config["modules"]["QRA"]["definitions"]
    if role in ("A2G", "SEAD"):
        assert definitions == []
    else:
        assert [d["name"] for d in definitions] == ["QRA-Maykop"]
        assert definitions[0]["active_at_start"] is (role == "CAP")


@pytest.mark.parametrize("role", ROLES)
def test_the_on_demand_cap_by_role(role: str) -> None:
    variant, _ = _build(role)
    kept = [c["group_name"] for c in variant.config["cap_missions"]]
    assert kept == ([] if role in ("A2G", "SEAD") else ["CAP-Red"])


def test_the_night_mission_and_configuration_are_left_untouched() -> None:
    mission, yaml_data = _mission(), _yaml()
    before = (copy.deepcopy(mission), copy.deepcopy(yaml_data))
    for role in ROLES:
        plan_variant(role, yaml_data, mission)
    assert (mission, yaml_data) == before


def test_cap_without_a_declared_qra_warns() -> None:
    yaml_data = _yaml()
    yaml_data["training"]["elements"] = [e for e in yaml_data["training"]["elements"] if "qra" not in e]
    variant, _ = _build("CAP", yaml_data)
    assert any("no QRA" in warning for warning in variant.warnings)
    assert not plan_variant("A2G", yaml_data, _mission()).warnings


# ── draws ──────────────────────────────────────────────────────────────────────────────────────


class TestDrawInAnExistingZone:
    """The SA-8 already belong to the Factory zone: the draw lives there, nothing is renamed."""

    def test_no_zone_is_injected(self) -> None:
        variant, built = _build("A2G")
        assert [z["name"] for z in built["triggers"]["zones"]] == ["Factory", "TRAINING-column"]
        assert [z["zone_name"] for z in variant.config["modules"]["COMBATZONE"]["combat_zones"]] == [
            "Factory",
            "TRAINING-column",
        ]

    def test_the_adopted_group_carries_the_markers_and_the_count(self) -> None:
        _, built = _build("ALL")
        names = [name for name in _units(built) if name.startswith("Factory-SA-8 #1-1")]
        assert names == ['Factory-SA-8 #1-1 #spawngroup="training-fdef" #spawncount=1-2 #spawnradius=500-2000']

    def test_the_command_candidate_rides_a_carrier_of_the_replaced_class(self) -> None:
        _, built = _build("ALL")
        units = _units(built)
        carriers = [u for name, u in units.items() if '#command="-sa15"' in name]
        assert len(carriers) == 1
        assert carriers[0]["type"] == "Osa 9A33 ln"
        assert '#spawngroup="training-fdef"' in carriers[0]["name"] and "#spawncount" not in carriers[0]["name"]
        assert "Factory-fdef-2" in group_names(built)

    def test_the_units_candidate_is_a_new_ground_group(self) -> None:
        _, built = _build("ALL")
        group = next(
            g for g in built["coalition"]["red"]["country"][0]["vehicle"]["group"] if g["name"] == "Factory-fdef-3"
        )
        assert [u["type"] for u in group["units"]] == ["Strela-10M3", "Strela-10M3"]
        assert "#spawnradius=500-2000" in group["units"][0]["name"] and "#spawn" not in group["units"][1]["name"]
        assert group["units"][0]["unitId"] > 0 and group["groupId"] > 0

    def test_the_draw_survives_the_removal_of_its_a2g_zone(self) -> None:
        """CAP takes the Factory targets out, not the defences drawn there."""
        _, built = _build("CAP")
        names = group_names(built)
        assert "Factory-Tanks" not in names
        assert {"Factory-SA-8 #1", "Factory-fdef-2", "Factory-fdef-3", "Factory-SA-6"} <= set(names)


class TestDrawInAnInjectedZone:
    """The column belongs to no zone: the build injects one and renames the adopted group under it."""

    def test_the_zone_is_injected_around_the_column(self) -> None:
        variant, built = _build("SEAD")
        zone = next(z for z in built["triggers"]["zones"] if z["name"] == "TRAINING-column")
        assert (zone["x"], zone["y"]) == (20300.0, 20000.0)
        assert zone["radius"] >= 500
        entry = variant.config["modules"]["COMBATZONE"]["combat_zones"][-1]
        assert entry == {
            "zone_name": "TRAINING-column",
            "friendly_name": "TRAINING-column",
            "active_at_start": True,
            "radio_menu_disabled": True,
            "user_activation_disabled": True,
            "completable": False,
        }

    def test_the_adopted_group_is_renamed_under_the_zone(self) -> None:
        _, built = _build("SEAD")
        names = group_names(built)
        assert "Column 1" not in names and "TRAINING-column-Column 1" in names
        assert 'Column 1-1 #spawngroup="training-column" #spawncount=1 #spawnradius=0-500' in _units(built)

    def test_a_referenced_group_cannot_be_renamed(self) -> None:
        refs = [("src/scripts/custom.lua", 'local g = Group.getByName("Column 1")')]
        with pytest.raises(TrainingError, match=r"'Column 1' is named in src/scripts/custom.lua"):
            plan_variant("ALL", _yaml(), _mission(), refs)

    def test_a_group_referenced_in_mission_yaml_cannot_be_renamed(self) -> None:
        yaml_data = _yaml(assets=["Column 1"])
        refs = reference_sources(None, yaml_data, _mission())
        with pytest.raises(TrainingError, match=r"'Column 1' is named in mission.yaml"):
            plan_variant("ALL", yaml_data, _mission(), refs)

    def test_a_referenced_group_that_keeps_its_name_is_fine(self) -> None:
        refs = [("src/scripts/custom.lua", 'Group.getByName("Factory-SA-8 #1")')]
        plan_variant("ALL", _yaml(), _mission(), refs)

    def test_the_combat_zone_module_is_created_when_absent(self) -> None:
        yaml_data = _yaml()
        yaml_data["training"]["elements"] = []
        yaml_data["training"]["randomize"] = yaml_data["training"]["randomize"][1:]
        del yaml_data["modules"]["COMBATZONE"]
        variant, _ = _build("ALL", yaml_data)
        assert variant.config["modules"]["COMBATZONE"]["enabled"] is True
        assert [z["zone_name"] for z in variant.config["modules"]["COMBATZONE"]["combat_zones"]] == ["TRAINING-column"]


def _draw(**overrides: Any) -> dict[str, Any]:
    draw = {"name": "d", "replaces": ["Column *"], "pool": [{"group": "Column 1"}]}
    draw.update(overrides)
    return draw


@pytest.mark.parametrize(
    ("training", "fragment"),
    [
        ({"elements": [{"groups": ["Nobody*"], "kind": "sam_lr"}]}, "no group of the mission matches 'Nobody*'"),
        ({"elements": [{"zone": "Nowhere", "kind": "a2g_target"}]}, "no combat zone 'Nowhere'"),
        ({"elements": [{"qra": "Nope", "kind": "qra"}]}, "no QRA named 'Nope'"),
        ({"elements": [{"cap_mission": "Nope", "kind": "enemy_cap"}]}, "group_name 'Nope'"),
        (
            {
                "elements": [
                    {"groups": ["Blue HQ"], "kind": "sam_lr"},
                    {"groups": ["Blue*"], "kind": "a2g_target"},
                ]
            },
            "declared both",
        ),
        (
            {"elements": [{"groups": ["Column 2"], "kind": "a2g_target"}], "randomize": [_draw()]},
            "a vague element is drawn, not classified",
        ),
        ({"randomize": [_draw(pool=[{"group": "Blue HQ"}])]}, "must also be listed by 'replaces'"),
        ({"randomize": [_draw(pool=[{"command": "-nothing-like-it"}])]}, "not a VEAF shortcut"),
        ({"randomize": [_draw(pool=[{"units": [{"type": "Tank of Theseus"}]}])]}, "not a DCS unit type"),
        ({"randomize": [_draw(pool=[{"units": [{"type": "MiG-29S"}]}])]}, "not a ground unit"),
        ({"randomize": [_draw(replaces=["Red CAP*"], pool=[{"command": "-sa8"}])]}, "ground groups and statics only"),
        (
            {"randomize": [_draw(), _draw(name="e", replaces=["Column 2"], pool=[{"command": "-armor"}])]},
            "replaced by two draws",
        ),
    ],
)
def test_a_block_that_does_not_fit_the_mission_is_refused(training: dict[str, Any], fragment: str) -> None:
    with pytest.raises(TrainingError) as caught:
        plan_variant("ALL", _yaml(training=training), _mission())
    assert fragment in str(caught.value)


def test_a_command_with_no_ground_unit_to_carry_it_needs_a_carrier() -> None:
    mission = _mission()
    mission["coalition"]["red"]["country"][0]["static"] = {
        "group": [_group("Depot", [_unit("Depot", "Fortification Tower", 5, 5)])]
    }
    training = {"randomize": [_draw(replaces=["Depot"], pool=[{"command": "-armor"}])]}
    with pytest.raises(TrainingError, match="give the candidate a 'carrier'"):
        plan_variant("ALL", _yaml(training=training), mission)
    training["randomize"][0]["pool"][0]["carrier"] = "T-72B"
    plan_variant("ALL", _yaml(training=training), mission)


def test_an_interpreter_carrier_cannot_be_adopted() -> None:
    """Its command runs at mission start and the carrier is destroyed: found on the demo, 2026-11-03."""
    mission = _mission()
    column = next(g for g in mission["coalition"]["red"]["country"][0]["vehicle"]["group"] if g["name"] == "Column 1")
    column["units"][0]["name"] = '#veafInterpreter["_name point Kobuleti City"]'
    with pytest.raises(TrainingError, match="#veafInterpreter"):
        plan_variant("ALL", _yaml(), mission)
    replaced_only = _yaml(training={"randomize": [_draw(pool=[{"command": "-armor"}])]})
    plan_variant("ALL", replaced_only, mission)


def test_an_adopted_static_takes_the_new_name_on_its_unit() -> None:
    """A static's zone membership is read off its own name."""
    mission = _mission()
    mission["coalition"]["red"]["country"][0]["static"] = {"group": [_group("Depot", [_unit("Depot", "Cargo1", 5, 5)])]}
    training = {"randomize": [_draw(replaces=["Depot"], pool=[{"group": "Depot"}])]}
    variant = plan_variant("ALL", _yaml(training=training), mission)
    apply_to_mission(mission, variant)
    assert 'TRAINING-d-Depot #spawngroup="training-d" #spawncount=1 #spawnradius=0' in _units(mission)


# ── profiles and the validator ─────────────────────────────────────────────────────────────────


def test_variant_profiles_and_derived_profiles() -> None:
    assert variant_profiles({}) == []
    assert variant_profiles(_yaml()) == ["TRAINING_A2G", "TRAINING_CAP", "TRAINING_SEAD", "TRAINING_ALL"]
    derived = with_training_profiles(_yaml(profiles={"TRAINING_CAP": {"global_log_level": "debug"}}))
    assert derived["profiles"]["TRAINING_A2G"] == {"training_variant": "A2G"}
    assert derived["profiles"]["TRAINING_CAP"] == {"training_variant": "CAP", "global_log_level": "debug"}
    assert with_training_profiles({"profiles": {}}) == {"profiles": {}}


def test_check_training_reports_every_problem() -> None:
    errors, warnings = check_training(_yaml(), _mission(), [])
    assert (errors, warnings) == ([], [])
    errors, _ = check_training(_yaml(build_variants=["MODERN"]), _mission(), [])
    assert any("build_variants" in e for e in errors)
    errors, _ = check_training(_yaml(training={"elements": [{"qra": "Nope", "kind": "qra"}]}), _mission(), [])
    assert errors == ["training.elements[1]: no QRA named 'Nope' in modules.QRA.definitions"]
    assert check_training({}, _mission(), []) == ([], [])


def test_reference_sources_read_the_dictionary_and_the_custom_scripts(tmp_path: Path) -> None:
    l10n = tmp_path / "src" / "mission" / "l10n" / "DEFAULT"
    l10n.mkdir(parents=True)
    (l10n / "dictionary").write_text('dictionary = { ["DictKey_1"] = "trigger.action.x(\'Column 1\')" }')
    (tmp_path / "src" / "scripts").mkdir()
    (tmp_path / "src" / "scripts" / "mine.lua").write_text('Group.getByName("Column 1")')
    yaml_data = _yaml(custom_scripts={"scripts": [{"path": "src/scripts/mine.lua"}]})
    labels = [label for label, _ in reference_sources(tmp_path, yaml_data, _mission())]
    assert "src/mission/l10n/DEFAULT/dictionary" in labels and "src/scripts/mine.lua" in labels
    with pytest.raises(TrainingError) as caught:
        plan_variant("ALL", yaml_data, _mission(), reference_sources(tmp_path, yaml_data, _mission()))
    assert "dictionary" in str(caught.value) and "mine.lua" in str(caught.value)


def test_cap_keeps_an_air_defence_even_declared_as_a_target() -> None:
    """A SAM site that is itself an A2G target stays in CAP; SEAD takes it out with the targets."""
    yaml_data = _yaml()
    yaml_data["training"]["elements"].append({"groups": ["Factory-Shilka"], "kind": "a2g_target"})
    assert "Factory-Shilka" in group_names(_build("CAP", yaml_data)[1])
    assert "Factory-Shilka" not in group_names(_build("SEAD", yaml_data)[1])


@pytest.mark.parametrize(("role", "kept"), [("A2G", True), ("CAP", False), ("SEAD", False), ("ALL", True)])
def test_a_draw_of_targets_leaves_with_the_targets(role: str, kept: bool) -> None:
    """Blindés drawn in an A2G zone are A2G targets: CAP and SEAD go without them (Marteau du Golan, 2026-11-03)."""
    yaml_data = _yaml()
    yaml_data["training"]["randomize"].append(
        {"name": "tanks", "replaces": ["Factory-Tanks"], "pool": [{"group": "Factory-Tanks"}, {"command": "-armor"}]}
    )
    variant, built = _build(role, yaml_data)
    names = group_names(built)
    assert ("Factory-Tanks" in names) is kept
    assert ("Factory-tanks-2" in names) is kept
    assert any(d.draw.name == "tanks" for d in variant.draws) is kept


def test_a_draw_of_air_defences_is_a_threat_wherever_it_lives() -> None:
    """The SA-8 drawn in the Factory A2G zone stay in SEAD: drawing only air defences is drawing a threat."""
    _, built = _build("SEAD")
    assert {"Factory-SA-8 #1", "Factory-fdef-2", "Factory-fdef-3"} <= set(group_names(built))


def test_a_draw_kind_overrides_its_zone() -> None:
    """The column belongs to no zone, so it stays everywhere, unless its entry says it is a target."""
    yaml_data = _yaml()
    yaml_data["training"]["randomize"][1]["kind"] = "a2g_target"
    variant, built = _build("CAP", yaml_data)
    assert not {"Column 1", "Column 2", "TRAINING-column-Column 1"} & set(group_names(built))
    assert "TRAINING-column" not in [z["zone_name"] for z in variant.config["modules"]["COMBATZONE"]["combat_zones"]]
    assert "TRAINING-column" not in [z["name"] for z in built["triggers"]["zones"]]


def test_an_unknown_draw_kind_is_refused() -> None:
    raw = {"randomize": [{"name": "a", "replaces": "x", "pool": [{"group": "x"}], "kind": "tanker"}]}
    plan, errors = parse_training(raw)
    assert plan is None and any("unknown kind 'tanker'" in e for e in errors)
