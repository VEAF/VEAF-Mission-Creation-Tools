"""No dynamic-slot templates for a side with no base offering slots (FEAT-OBJECTIVE-MISSION-V2 11).

The shipped catalogue put red's templates on "Marteau du Golan", where red holds no slot base.
"""

from pathlib import Path

from aircrafts_injector.catalogue import filter_by_sides, iter_groups, load_catalogue
from veaf_libs.mission_validator import dynamic_slot_sides
from veaf_tools.commands.build import side_filtered_catalogue

SHIPPED = Path(__file__).parents[3] / "src" / "defaults" / "mission-folder" / "src" / "dynamic-slot-templates.yaml"

_WAREHOUSES = """warehouses =
{
    ["airports"] =
    {
        [1] = { ["coalition"] = "BLUE", ["dynamicSpawn"] = true },
        [2] = { ["coalition"] = "RED", ["dynamicSpawn"] = false },
        [3] = { ["coalition"] = "NEUTRAL", ["dynamicSpawn"] = true },
    },
}
"""


def _sides(catalogue: dict) -> set[str]:
    return {ref.coalition for ref, _ in iter_groups(catalogue)}


def _folder(tmp_path: Path, warehouses_yaml: str | None = None) -> Path:
    (tmp_path / "src" / "mission").mkdir(parents=True)
    (tmp_path / "src" / "mission" / "warehouses").write_text(_WAREHOUSES, encoding="utf-8")
    if warehouses_yaml is not None:
        (tmp_path / "src" / "warehouses.yaml").write_text(warehouses_yaml, encoding="utf-8")
    return tmp_path


def test_the_shipped_catalogue_carries_both_sides() -> None:
    assert _sides(load_catalogue(SHIPPED)) == {"blue", "red"}


def test_a_side_left_out_loses_every_template_and_only_those() -> None:
    catalogue = load_catalogue(SHIPPED)
    red = sum(1 for ref, _ in iter_groups(catalogue) if ref.coalition == "red")
    kept, removed = filter_by_sides(catalogue, {"blue"})
    assert (removed, _sides(kept)) == (red, {"blue"})
    assert _sides(catalogue) == {"blue", "red"}  # not modified


def test_only_a_side_with_a_slot_base_keeps_its_templates(tmp_path: Path) -> None:
    assert dynamic_slot_sides(_folder(tmp_path), {}) == {"blue"}


def test_a_side_warehouses_yaml_opens_keeps_them(tmp_path: Path) -> None:
    assert dynamic_slot_sides(_folder(tmp_path, "red:\n  airports: all\n"), {}) == {"blue", "red"}


def test_warehouses_yaml_switched_off_opens_nothing(tmp_path: Path) -> None:
    assert dynamic_slot_sides(_folder(tmp_path, "red:\n  airports: all\n"), {"warehouses": False}) == {"blue"}


def test_unreadable_warehouses_tell_nothing_and_leave_everything(tmp_path: Path) -> None:
    assert dynamic_slot_sides(tmp_path, {}) is None
    assert side_filtered_catalogue(SHIPPED, None, tmp_path) == (SHIPPED, 0)


def test_the_filtered_copy_is_what_gets_injected(tmp_path: Path) -> None:
    path, removed = side_filtered_catalogue(SHIPPED, {"blue"}, tmp_path / "sides")
    assert removed and path is not None and path != SHIPPED
    assert _sides(load_catalogue(path)) == {"blue"}
    assert side_filtered_catalogue(SHIPPED, {"blue", "red"}, tmp_path) == (SHIPPED, 0)
    assert side_filtered_catalogue(SHIPPED, set(), tmp_path)[0] is None
