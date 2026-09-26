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
    with pytest.raises(ValueError, match=r"unknown parameter.*miz_path.*expected.*mission_path.*verbose"):
        _strict_catalog().run_action("describe_map", {"mission_path": "x", "miz_path": "x"})


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
