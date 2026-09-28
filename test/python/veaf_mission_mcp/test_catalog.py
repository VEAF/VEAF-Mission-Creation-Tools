import pytest
from veaf_mission_mcp.catalog import ActionCatalog, ActionNotFoundError
from veaf_mission_mcp.models import ActionSpec


def _spec(name: str = "add_group") -> ActionSpec:
    return ActionSpec(
        name=name,
        description="Add a group.",
        parameters_schema={"type": "object", "properties": {}},
    )


def test_list_catalog_is_empty_by_default() -> None:
    catalog = ActionCatalog()

    assert catalog.list_catalog() == []


def test_register_makes_action_visible_in_list_catalog() -> None:
    catalog = ActionCatalog()
    spec = _spec()

    catalog.register(spec, handler=lambda params: None)

    assert catalog.list_catalog() == [spec]


def test_describe_action_returns_the_registered_spec() -> None:
    catalog = ActionCatalog()
    spec = _spec()
    catalog.register(spec, handler=lambda params: None)

    assert catalog.describe_action("add_group") == spec


def test_describe_action_raises_for_unknown_name() -> None:
    catalog = ActionCatalog()

    with pytest.raises(ActionNotFoundError):
        catalog.describe_action("does_not_exist")


def test_run_action_dispatches_params_to_the_registered_handler() -> None:
    catalog = ActionCatalog()
    received: dict[str, object] = {}

    def handler(params: dict[str, object]) -> str:
        received.update(params)
        return "ok"

    catalog.register(_spec(), handler=handler)

    result = catalog.run_action("add_group", {"coalition": "blue"})

    assert result == "ok"
    assert received == {"coalition": "blue"}


def test_run_action_raises_for_unknown_name() -> None:
    catalog = ActionCatalog()

    with pytest.raises(ActionNotFoundError):
        catalog.run_action("does_not_exist", {})


def _strict_catalog() -> ActionCatalog:
    catalog = ActionCatalog()
    spec = ActionSpec(
        name="describe_map",
        description="Describe a map.",
        parameters_schema={
            "type": "object",
            "properties": {"mission_path": {"type": "string"}, "verbose": {"type": "boolean"}},
            "required": ["mission_path"],
        },
    )
    catalog.register(spec, handler=lambda params: params)
    return catalog


def test_run_action_names_a_missing_required_parameter() -> None:
    with pytest.raises(ValueError, match="missing required parameter.*mission_path"):
        _strict_catalog().run_action("describe_map", {})


def test_run_action_names_an_unknown_parameter_and_the_expected_ones() -> None:
    with pytest.raises(ValueError, match=r"unknown parameter.*mision_path.*expected.*mission_path.*verbose"):
        _strict_catalog().run_action("describe_map", {"mission_path": "x", "mision_path": "x"})


def test_run_action_accepts_the_declared_parameters() -> None:
    assert _strict_catalog().run_action("describe_map", {"mission_path": "x", "verbose": True}) == {
        "mission_path": "x",
        "verbose": True,
    }


def test_a_schema_that_allows_extra_parameters_is_honoured() -> None:
    catalog = ActionCatalog()
    spec = ActionSpec(
        name="free",
        description="Free-form.",
        parameters_schema={"type": "object", "properties": {"a": {}}, "additionalProperties": True},
    )
    catalog.register(spec, handler=lambda params: params)
    assert catalog.run_action("free", {"b": 1}) == {"b": 1}


# FIX-OPEN-TRAINING-PROMPT-FINDINGS 05: the mission was named five ways across the catalogue.


def _mission_action(key: str, *, required: bool = True) -> ActionSpec:
    return ActionSpec(
        name="act",
        description="An action taking the mission.",
        parameters_schema={
            "type": "object",
            "properties": {key: {"type": "string"}, "other": {"type": "string"}},
            "required": [key] if required else [],
        },
    )


@pytest.mark.parametrize("native", ["miz_path", "target", "folder_path", "mission_path"])
def test_every_mission_key_is_published_as_mission_path(native: str) -> None:
    catalog = ActionCatalog()
    catalog.register(_mission_action(native), handler=lambda params: None)
    schema = catalog.describe_action("act").parameters_schema
    assert list(schema["properties"]) == ["mission_path", "other"]
    assert schema["required"] == ["mission_path"]


@pytest.mark.parametrize("given", ["miz_path", "target", "folder_path", "mission_path"])
def test_any_name_reaches_the_handler_under_its_own_key(given: str) -> None:
    catalog = ActionCatalog()
    received: dict = {}
    catalog.register(_mission_action("miz_path"), handler=received.update)
    catalog.run_action("act", {given: "m.miz", "other": "x"})
    assert received == {"miz_path": "m.miz", "other": "x"}


def test_the_mission_given_twice_with_two_values_is_refused() -> None:
    catalog = ActionCatalog()
    catalog.register(_mission_action("target"), handler=lambda params: None)
    with pytest.raises(ValueError, match="given twice"):
        catalog.run_action("act", {"mission_path": "a", "target": "b"})


def test_a_mission_folder_given_for_a_mission_yaml_is_read_as_its_mission_yaml(tmp_path) -> None:
    catalog = ActionCatalog()
    received: dict = {}
    catalog.register(_mission_action("mission_yaml_path"), handler=received.update)
    catalog.run_action("act", {"mission_path": str(tmp_path)})
    assert received == {"mission_yaml_path": str(tmp_path / "mission.yaml")}
    assert "mission_yaml_path" in catalog.describe_action("act").parameters_schema["properties"]


def test_no_shipped_action_introduces_another_name_for_the_mission() -> None:
    """A new action must take `mission_path` (or `mission_yaml_path`), never a sixth name."""
    from veaf_mission_mcp.actions import register_default_actions

    catalog = ActionCatalog()
    register_default_actions(catalog)
    allowed = {"mission_path", "mission_yaml_path", "source_path", "runtime_path", "sound_path"}
    offenders = {
        (spec.name, key)
        for spec in catalog.list_catalog()
        for key in (spec.parameters_schema.get("properties") or {})
        if (key.endswith("_path") or key in ("target", "miz", "folder", "mission")) and key not in allowed
    }
    assert offenders == set()
