"""An earlier build left beside the new one must be flagged.

`Test-MizNaming` compares the `.miz` files present with the name `mission.yaml` asks for, because
on the VEAF servers that name is an interface — RealWeather reads `_ICAO_<code>` from it. It
catches a file under a *different* name. It said nothing about
`VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz` sitting next to `…_20260825.miz`: same base name,
only the date differs, so both counted as matching.

Deploying the old one is silent and wrong, so the batch flags it now.

The build names its output `<name>_<YYYYMMDD>[_<VARIANT>].miz` (`build.py`), which is what makes
this decidable rather than a guess: group by name *and* variant, and within a group only the
latest date is the current build. Two variants of the same day are not a duplicate — that is what
`build_variants:` produces on purpose — and a file carrying no date is left alone.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
HELPER = REPO_ROOT / "tools" / "Get-SupersededMiz.ps1"
BATCH = REPO_ROOT / "tools" / "Convert-FootholdBatch.ps1"
PWSH = shutil.which("pwsh")


@unittest.skipUnless(PWSH, "pwsh not available")
class TestSupersededMiz(unittest.TestCase):
    def _superseded(self, names: list[str]) -> list[str]:
        """Return the names the helper considers left over from an earlier build."""
        assert PWSH is not None
        quoted = ",".join(f"'{name}'" for name in names)
        script = f". '{HELPER}'; @(Get-SupersededMiz -Names @({quoted})) | ConvertTo-Json -AsArray -Compress"
        done = subprocess.run(
            [PWSH, "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=120,
        )
        self.assertEqual(done.returncode, 0, f"pwsh failed: {done.stderr}")
        return json.loads(done.stdout or "[]")

    def test_the_previous_build_is_flagged(self) -> None:
        # The real case, from the 2026-08-25 refresh.
        superseded = self._superseded(
            [
                "VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz",
                "VEAF_Foothold_Caucasus_ICAO_URSS_20260825.miz",
            ]
        )

        self.assertEqual(superseded, ["VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz"])

    def test_a_single_build_is_not_flagged(self) -> None:
        self.assertEqual(self._superseded(["VEAF_Foothold_Caucasus_ICAO_URSS_20260825.miz"]), [])

    def test_two_variants_of_the_same_day_are_both_current(self) -> None:
        # `build_variants: [MODERN, COLD_WAR]` emits exactly this in one build.
        self.assertEqual(
            self._superseded(["Foothold_20260825_MODERN.miz", "Foothold_20260825_COLD_WAR.miz"]),
            [],
        )

    def test_a_variant_is_compared_against_its_own_previous_build(self) -> None:
        superseded = self._superseded(
            [
                "Foothold_20260728_MODERN.miz",
                "Foothold_20260825_MODERN.miz",
                "Foothold_20260825_COLD_WAR.miz",
            ]
        )

        self.assertEqual(superseded, ["Foothold_20260728_MODERN.miz"])

    def test_a_file_with_no_date_is_left_alone(self) -> None:
        # A hand-named .miz is not ours to judge; `Test-MizNaming` already reports the odd name.
        self.assertEqual(self._superseded(["MyOwnMission.miz", "Foothold_20260825.miz"]), [])

    def test_three_builds_leave_only_the_newest(self) -> None:
        superseded = self._superseded(["Foothold_20260618.miz", "Foothold_20260728.miz", "Foothold_20260825.miz"])

        self.assertEqual(sorted(superseded), ["Foothold_20260618.miz", "Foothold_20260728.miz"])

    def test_different_missions_never_shadow_each_other(self) -> None:
        self.assertEqual(
            self._superseded(["Foothold_Caucasus_20260728.miz", "Foothold_Syria_20260825.miz"]),
            [],
        )


@unittest.skipUnless(PWSH, "pwsh not available")
class TestTheBatchUsesIt(unittest.TestCase):
    """The helper working proves nothing if the batch never calls it."""

    def test_the_batch_calls_the_helper(self) -> None:
        assert PWSH is not None
        script = (
            f"$ast = [System.Management.Automation.Language.Parser]::ParseFile('{BATCH}', [ref]$null, [ref]$null); "
            "@($ast.FindAll({ param($n) $n -is "
            "[System.Management.Automation.Language.CommandAst] -and "
            "$n.GetCommandName() -eq 'Get-SupersededMiz' }, $true)).Count"
        )
        done = subprocess.run(
            [PWSH, "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=120,
        )

        self.assertEqual(done.returncode, 0, f"pwsh failed: {done.stderr}")
        self.assertNotEqual(done.stdout.strip(), "0", "the batch must actually run the check")


if __name__ == "__main__":
    unittest.main()
