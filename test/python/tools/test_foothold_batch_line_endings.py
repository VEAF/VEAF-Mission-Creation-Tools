"""`Convert-FootholdBatch` must not change a mission.yaml's line endings — FIX-FOOTHOLD-5-3-0-INTAKE.

After each build the batch removes the machine-specific ``build.scripts_path`` key the build
persists. It wrote the file back with ``WriteAllLines``, which ends every line with the platform's
newline: on Windows an LF ``VEAF-Foothold-Caucasus/mission.yaml`` came back CRLF, a diff on every
line in a repository that keeps files byte-for-byte (``* -text``), for one removed key (2026-10-17).

The batch takes mandatory parameters and would start converting if sourced, so the functions under
test are lifted out of its syntax tree and defined on their own.
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
BATCH = REPO_ROOT / "tools" / "Convert-FootholdBatch.ps1"
PWSH = shutil.which("pwsh")

_YAML = "mission:\n  name: X\nbuild:\n  scripts_path: C:/somewhere/published\n  dev_mode: false\n"


@unittest.skipUnless(PWSH, "pwsh not available")
class TestRemovePersistedScriptsPath(unittest.TestCase):
    def _run_on(self, content: bytes) -> bytes:
        assert PWSH is not None
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mission.yaml"
            path.write_bytes(content)
            script = (
                f"$ast = [System.Management.Automation.Language.Parser]::ParseFile('{BATCH}', [ref]$null, [ref]$null); "
                "$wanted = 'Read-Utf8Lines', 'Write-Utf8Lines', 'Remove-PersistedScriptsPath'; "
                "$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] "
                "-and $wanted -contains $n.Name }, $true) | ForEach-Object { Invoke-Expression $_.Extent.Text }; "
                f"Remove-PersistedScriptsPath -MissionYaml '{path}'"
            )
            done = subprocess.run(
                [PWSH, "-NoProfile", "-NonInteractive", "-Command", script],
                capture_output=True,
                text=True,
                timeout=120,
            )
            self.assertEqual(done.returncode, 0, f"pwsh failed: {done.stderr}")
            return path.read_bytes()

    def test_an_lf_file_stays_lf(self) -> None:
        result = self._run_on(_YAML.encode("utf-8"))

        self.assertNotIn(b"\r", result)
        self.assertEqual(b"mission:\n  name: X\nbuild:\n  dev_mode: false\n", result)

    def test_a_crlf_file_stays_crlf(self) -> None:
        result = self._run_on(_YAML.replace("\n", "\r\n").encode("utf-8"))

        self.assertEqual(b"mission:\r\n  name: X\r\nbuild:\r\n  dev_mode: false\r\n", result)


if __name__ == "__main__":
    unittest.main()
