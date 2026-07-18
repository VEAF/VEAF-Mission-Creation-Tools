"""`veaf-tools mcp` starts the mission-editing MCP server."""

from __future__ import annotations

import unittest
from unittest import mock

import veaf_tools.commands  # noqa: F401 — registers commands on `app`
from typer.testing import CliRunner
from veaf_tools.app import app

_runner = CliRunner()


class TestMcpCommand(unittest.TestCase):
    def test_mcp_command_delegates_to_the_server(self) -> None:
        with mock.patch("veaf_mission_mcp.server.main") as run_server:
            result = _runner.invoke(app, ["mcp"])
        self.assertEqual(result.exit_code, 0, result.output)
        run_server.assert_called_once()


if __name__ == "__main__":
    unittest.main()
