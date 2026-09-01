"""The module registry and the generator's order must keep describing the same tree.

Two lists say which VEAF modules get initialised, and neither knows about the other:

* the Lua registry — one ``veaf.registerModule(<module>.Id, …)`` call per module file;
* ``_MODULE_INIT_ORDER`` in ``lua_config_generator.py`` — the order the generated
  ``veaf-config.lua`` actually calls them in.

They drifted apart once already: five modules the generator initialises on every mission
(``UNITS``, ``TIME``, ``CACHE``, ``MARKERS``, ``SKYNET_MONITOR``) had never registered, and nobody
noticed because nothing reads the registry yet. These tests fail the next time it happens, in
either direction, and they also read the table in ``docs/agents/module-initialisation.md`` back and
check it against the code — a table nothing verifies is accurate for a week.

See CHORE-INIT-REGISTRY-TELLS-THE-TRUTH.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from veaf_libs.lua_config_generator import _MODULE_INIT_ORDER, _NO_INIT_MODULES
from veaf_libs.lua_module_scanner import ModuleInitFacts, find_lua_scripts_dir, scan_module_initialisation

#: Modules that register but hold no declared place in ``_MODULE_INIT_ORDER``, so the generator
#: calls them from its unordered bucket, just before ``INTERPRETER``.
#:
#: Not an oversight left to rot: giving either of them a place changes what every mission's
#: ``veaf-config.lua`` contains, which belongs to the lot that makes the generated config call
#: ``veaf.initialize()``. Documented in ``docs/agents/module-initialisation.md``.
UNORDERED_BY_DESIGN: frozenset[str] = frozenset({"COMMANDS", "MISSIONDB"})

#: Modules in neither mechanism: libraries that publish onto ``veaf.*`` when their file loads.
#: Their ``initialize()``, where they have one, logs a line and does nothing else.
LIBRARY_MODULES: frozenset[str] = frozenset({"GEO", "I18N", "MATH", "SCHEDULER", "SPAWNER"})

#: Modules known to initialise themselves at load time, on purpose. Both are read from the top
#: level of other modules' files, so waiting for an init pass would be too late.
SELF_INITIALISING: frozenset[str] = frozenset({"EVENTS", "MISSIONDB"})

_DOC_PATH = Path(__file__).resolve().parents[3] / "docs" / "agents" / "module-initialisation.md"
_TABLE_START = "<!-- MODULE-INIT-TABLE-START -->"
_TABLE_END = "<!-- MODULE-INIT-TABLE-END -->"


def _facts() -> dict[str, ModuleInitFacts]:
    """Scan the repository's Lua sources, skipping the test when they are not reachable."""
    lua_dir = find_lua_scripts_dir()
    if lua_dir is None:  # pragma: no cover - only outside a repo checkout
        raise unittest.SkipTest("src/scripts/veaf not found")
    return scan_module_initialisation(lua_dir)


class TestRegistryMatchesGenerator(unittest.TestCase):
    """The two lists must cover the same modules."""

    def setUp(self) -> None:
        self.facts = _facts()
        self.registered = {mid for mid, f in self.facts.items() if f["registers"]}
        self.ordered = set(_MODULE_INIT_ORDER)

    def test_every_module_the_generator_initialises_registers(self) -> None:
        """A module in ``_MODULE_INIT_ORDER`` must register — unless it has no ``initialize()``."""
        expected_to_register = self.ordered - set(_NO_INIT_MODULES)
        missing = sorted(expected_to_register - self.registered)
        self.assertEqual(
            missing,
            [],
            f"{missing} are initialised by the generated veaf-config.lua but never call "
            "veaf.registerModule — add the registration, or add the module to _NO_INIT_MODULES "
            "if it has no initialize(). See docs/agents/module-initialisation.md.",
        )

    def test_every_registered_module_has_a_place_in_the_generator_order(self) -> None:
        """A module that registers must sit in ``_MODULE_INIT_ORDER``, or be listed as unordered."""
        unplaced = sorted(self.registered - self.ordered - UNORDERED_BY_DESIGN)
        self.assertEqual(
            unplaced,
            [],
            f"{unplaced} call veaf.registerModule but hold no place in _MODULE_INIT_ORDER, so the "
            "generator calls them from its unordered bucket just before INTERPRETER. Give them a "
            "position, or add them to UNORDERED_BY_DESIGN and say why in "
            "docs/agents/module-initialisation.md.",
        )

    def test_unordered_by_design_holds_no_stale_entry(self) -> None:
        """The exception list must not outlive the exceptions."""
        stale = sorted(mid for mid in UNORDERED_BY_DESIGN if mid in self.ordered or mid not in self.registered)
        self.assertEqual(stale, [], f"{stale} no longer need the UNORDERED_BY_DESIGN exception — drop them from it.")

    def test_no_init_modules_are_exactly_the_ordered_ones_without_initialize(self) -> None:
        """``_NO_INIT_MODULES`` must cover every listed module the generator cannot call."""
        cannot_be_called = {mid for mid in self.ordered if not self.facts[mid]["has_initialize"]}
        self.assertEqual(
            set(_NO_INIT_MODULES),
            cannot_be_called,
            "_NO_INIT_MODULES must name exactly the modules in _MODULE_INIT_ORDER that define no "
            "initialize(); anything else emits a call to a nil value.",
        )

    def test_modules_in_neither_mechanism_are_the_known_libraries(self) -> None:
        """A new module file must land in one of the two lists, or be declared a library."""
        orphans = {mid for mid, f in self.facts.items() if not f["registers"] and mid not in self.ordered}
        self.assertEqual(
            orphans,
            set(LIBRARY_MODULES),
            "a module belonging to neither mechanism is never initialised. Register it, give it a "
            "place in _MODULE_INIT_ORDER, or declare it a library in LIBRARY_MODULES.",
        )

    def test_self_initialising_modules_are_the_declared_ones(self) -> None:
        """Initialising at load time is a deliberate exception; it must stay a listed one."""
        self_init = {mid for mid, f in self.facts.items() if f["self_initialises"]}
        self.assertEqual(
            self_init,
            set(SELF_INITIALISING),
            "a module that calls its own initialize() at load time is initialised twice on a "
            "mission that also enables it — declare it in SELF_INITIALISING and say why in place, "
            "the way veafMissionDb does.",
        )

    def test_i18n_has_no_initialize_and_no_exemption(self) -> None:
        """Pin the one gap this lot deliberately did not close.

        ``I18N`` shows up in the generated ``mission.yaml`` template like every other module, so a
        mission that enables it gets ``veafI18n.initialize()`` emitted — a nil call. It escapes
        :meth:`test_no_init_modules_are_exactly_the_ordered_ones_without_initialize` only because
        it holds no place in ``_MODULE_INIT_ORDER``. Closing it changes generated output, which is
        out of this lot's scope; this assertion makes sure the fix comes with a doc update.
        """
        self.assertFalse(self.facts["I18N"]["has_initialize"])
        self.assertNotIn("I18N", _NO_INIT_MODULES)


class TestDocumentedTableMatchesTheCode(unittest.TestCase):
    """``docs/agents/module-initialisation.md`` must describe the tree as it is."""

    def setUp(self) -> None:
        self.facts = _facts()

    @staticmethod
    def _documented_rows() -> dict[str, tuple[str, str, str, str, str]]:
        """Parse the fenced table out of the doc, keyed by module ID."""
        text = _DOC_PATH.read_text(encoding="utf-8")
        body = text.split(_TABLE_START, 1)[1].split(_TABLE_END, 1)[0]
        rows: dict[str, tuple[str, str, str, str, str]] = {}
        for line in body.splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) != 6 or not cells[0].startswith("`"):
                continue
            module_id = cells[0].strip("`")
            rows[module_id] = (cells[1], cells[2], cells[3], cells[4], cells[5])
        return rows

    def _expected_row(self, module_id: str) -> tuple[str, str, str, str, str]:
        facts = self.facts[module_id]
        position = _MODULE_INIT_ORDER.index(module_id) if module_id in _MODULE_INIT_ORDER else None
        generator = "--" if position is None else str(position)
        if module_id in _NO_INIT_MODULES:
            generator += " (data only)"
        return (
            f"`{facts['var_name']}`",
            str(facts["order"]) if facts["registers"] else "--",
            generator,
            "yes" if facts["self_initialises"] else "--",
            f"`initialize({facts['init_params']})`" if facts["has_initialize"] else "--",
        )

    def test_the_table_lists_every_module_and_nothing_else(self) -> None:
        self.assertEqual(sorted(self._documented_rows()), sorted(self.facts))

    def test_every_row_matches_the_sources(self) -> None:
        documented = self._documented_rows()
        wrong = {
            mid: (row, self._expected_row(mid)) for mid, row in documented.items() if row != self._expected_row(mid)
        }
        self.assertEqual(
            wrong,
            {},
            "docs/agents/module-initialisation.md no longer describes the code (documented, actual). Update the table.",
        )

    def test_the_doc_names_the_test_that_guards_it(self) -> None:
        """A table nobody knows is checked gets edited by hand and quietly broken."""
        self.assertIn(Path(__file__).name, _DOC_PATH.read_text(encoding="utf-8"))


class TestScanMatchesTheRawSources(unittest.TestCase):
    """Guard the scanner itself: the census is only worth what its parser is worth."""

    def setUp(self) -> None:
        self.lua_dir = find_lua_scripts_dir()
        if self.lua_dir is None:  # pragma: no cover - only outside a repo checkout
            raise unittest.SkipTest("src/scripts/veaf not found")
        self.facts = scan_module_initialisation(self.lua_dir)

    def test_finds_every_register_module_call_in_the_tree(self) -> None:
        """The count must match a raw text search, minus the two non-module call sites in veaf.lua.

        ``veaf.lua`` holds three occurrences: the ``function veaf.registerModule(id, …)``
        declaration, a mention inside a doc comment, and the CTLD registration. Only real
        registrations keyed on ``<table>.Id`` are counted here.
        """
        raw = sum(
            len(re.findall(r"veaf\.registerModule\s*\(", f.read_text(encoding="utf-8", errors="ignore")))
            for f in sorted(self.lua_dir.glob("veaf*.lua"))
        )
        registered = sum(1 for f in self.facts.values() if f["registers"])
        self.assertEqual(raw - 3, registered, "raw registerModule occurrences no longer match the parsed registry")

    def test_closure_registrations_are_recognised(self) -> None:
        """Four modules pass an inline closure instead of a function reference.

        A regular expression tight enough to skip a closure body drops these four silently, which
        is how an earlier count reported 23 registered modules where there were 26.
        """
        wrapped = {mid for mid, f in self.facts.items() if f["wrapped"]}
        self.assertEqual(wrapped, {"NAMEDPOINTS", "RADIO", "SKYNET", "WEATHER"})

    def test_commented_out_calls_are_not_counted(self) -> None:
        """``veafAirbases`` and ``veafWeather`` both hold a ``--[[ … ]]`` block calling initialize()."""
        self.assertFalse(self.facts["AIRBASES"]["self_initialises"])
        self.assertFalse(self.facts["WEATHER"]["self_initialises"])
