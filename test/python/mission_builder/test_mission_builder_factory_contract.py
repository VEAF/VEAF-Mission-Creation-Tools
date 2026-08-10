"""The test factory must default *every* field `MissionBuilderWorker.__init__` assigns.

Without this check, adding a field to `__init__` still breaks the hand-built workers —
just in one place instead of fifteen, and with the same unattributed `AttributeError`.
Here the failure names the missing field and where to add it.
"""

from __future__ import annotations

import ast
import inspect
import textwrap

import pytest
from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_builder_factory import init_field_defaults, make_worker


def _fields_assigned_in_init() -> set[str]:
    """Return the names of every `self.<name>` assignment in `__init__`.

    Read from the source rather than from an instance: constructing a real worker needs
    a mission folder, and a field assigned only inside a branch would be missed anyway.

    Returns:
        The attribute names, including those assigned in nested branches.
    """
    source = textwrap.dedent(inspect.getsource(MissionBuilderWorker.__init__))
    names: set[str] = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Assign):
            targets = list(node.targets)
        elif isinstance(node, (ast.AnnAssign, ast.AugAssign)):
            targets = [node.target]
        else:
            continue
        for target in targets:
            if isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name):
                if target.value.id == "self":
                    names.add(target.attr)
    return names


class TestFactoryCoversInit:
    def test_every_init_field_has_a_default(self) -> None:
        """A field added to `__init__` must gain a default in `init_field_defaults`."""
        missing = sorted(_fields_assigned_in_init() - set(init_field_defaults()))
        assert not missing, (
            f"MissionBuilderWorker.__init__ assigns {missing}, which make_worker() leaves unset. "
            f"Add one entry per field to init_field_defaults() in "
            f"test/python/testlib/mission_builder_factory.py."
        )

    def test_no_default_for_a_field_init_no_longer_assigns(self) -> None:
        """A field dropped from `__init__` must lose its default, or it hides a rename."""
        stale = sorted(set(init_field_defaults()) - _fields_assigned_in_init())
        assert not stale, (
            f"init_field_defaults() defaults {stale}, which MissionBuilderWorker.__init__ no "
            f"longer assigns. Remove the entry (or fix the name if it was renamed)."
        )

    def test_the_shell_carries_every_field(self) -> None:
        """The worker really has the attributes, not just the defaults table."""
        worker = make_worker()
        for name in _fields_assigned_in_init():
            assert hasattr(worker, name), name


class TestOverrides:
    def test_override_replaces_the_default(self) -> None:
        assert make_worker(dev_mode=True).dev_mode is True

    def test_mutable_defaults_are_not_shared(self) -> None:
        """Two workers must not share the same list — one test would pollute the next."""
        first, second = make_worker(), make_worker()
        first.custom_scripts.append("x")  # type: ignore[arg-type]
        assert second.custom_scripts == []

    def test_unknown_field_is_rejected(self) -> None:
        """A typo must fail here, not silently create an attribute nothing reads."""
        with pytest.raises(TypeError, match="dev_mod"):
            make_worker(dev_mod=True)

    def test_output_mission_derives_from_the_mission_folder(self, tmp_path) -> None:
        assert make_worker(mission_folder=tmp_path).output_mission == tmp_path / "out.miz"

    def test_explicit_output_mission_wins(self, tmp_path) -> None:
        target = tmp_path / "elsewhere.miz"
        assert make_worker(mission_folder=tmp_path, output_mission=target).output_mission == target

    def test_no_folder_by_default(self) -> None:
        """The "no mission folder needed" property: nothing is created unless asked for."""
        worker = make_worker()
        assert worker.mission_folder is None
        assert worker.output_mission is None
