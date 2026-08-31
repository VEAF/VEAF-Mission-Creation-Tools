"""Tests for the `veaf-build update-dcs-data` command dispatch (no network)."""

from __future__ import annotations

import unittest
from unittest import mock

from typer.testing import CliRunner

from veaf_build.cli import app


class TestUpdateDcsDataDispatch(unittest.TestCase):
    """The command routes to the right providers without touching the network."""

    def setUp(self) -> None:
        self.runner = CliRunner()

    def _run(self, *args: str) -> tuple[mock.MagicMock, mock.MagicMock, int]:
        """Invoke the command with every generator patched; return the countries and radio mocks.

        The units generators are patched too, and that is not tidiness: ``--all`` runs them, and
        ``units.generate`` **clones the datamine repository from GitHub**. Left unpatched, three of
        these tests each performed a network clone, and rapid successive clones fail — measured at 2
        to 3 failures per run, at random, which reddens CI for reasons that have nothing to do with
        the change under review. What these tests assert is dispatch: which providers a flag selects.
        Nothing here needs a real clone.
        """
        with (
            mock.patch("veaf_build.dcs_data.countries.generate", return_value=92) as gen_countries,
            mock.patch("veaf_build.radio_specs_updater.main") as gen_radio,
            mock.patch("veaf_build.dcs_data.units.generate", return_value=873),
            mock.patch("veaf_build.dcs_data.units_lua.generate", return_value=873),
        ):
            result = self.runner.invoke(app, ["update-dcs-data", *args])
        return gen_countries, gen_radio, result.exit_code

    def test_countries_flag_runs_only_countries(self) -> None:
        """--countries regenerates the country table and nothing else."""
        gen_countries, gen_radio, code = self._run("--countries")
        self.assertEqual(code, 0)
        gen_countries.assert_called_once()
        gen_radio.assert_not_called()

    def test_radio_flag_runs_only_radio(self) -> None:
        """--radio regenerates the radio specs and nothing else."""
        gen_countries, gen_radio, code = self._run("--radio")
        self.assertEqual(code, 0)
        gen_radio.assert_called_once()
        gen_countries.assert_not_called()

    def test_all_runs_countries_but_skips_radio(self) -> None:
        """--all (and the no-flag default) regenerates countries but skips radio.

        Radio carries manual overlays the generator cannot reproduce, so it must
        not be regenerated implicitly.
        """
        gen_countries, gen_radio, code = self._run("--all")
        self.assertEqual(code, 0)
        gen_countries.assert_called_once()
        gen_radio.assert_not_called()

    def test_no_flag_defaults_to_all(self) -> None:
        """With no flag, the command behaves like --all."""
        gen_countries, gen_radio, code = self._run()
        self.assertEqual(code, 0)
        gen_countries.assert_called_once()
        gen_radio.assert_not_called()

    def test_all_and_radio_runs_both(self) -> None:
        """An explicit --radio is honored even when combined with --all."""
        gen_countries, gen_radio, code = self._run("--all", "--radio")
        self.assertEqual(code, 0)
        gen_countries.assert_called_once()
        gen_radio.assert_called_once()


if __name__ == "__main__":
    unittest.main()
