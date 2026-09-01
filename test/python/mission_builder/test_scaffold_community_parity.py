"""The two ways to scaffold a `mission.yaml` must agree on the opt-out community scripts.

**Why this exists** (FIX-SCAFFOLD-OPTOUT-DRIFT). There are two scaffolds, and they used to
contradict each other:

- `src/defaults/mission-folder/mission.yaml`, copied as-is, lists `STTS/CTLD/AIEN/CSAR/SKYNET`
  at `false` — the five are off;
- `prepare --template <tier>` omitted every module the tier does not include, and for an
  **opt-out** community script absence means *enabled*. So `--template minimal` shipped five
  community scripts, and the build warned that CTLD was misconfigured in a mission that never
  mentions CTLD.

The drift survived because each side was tested alone and each was self-consistent with itself.
These tests compare them **against each other**, through the build's own decision function
(`MissionBuilderWorker._community_enabled`), which is what actually settles what a mission runs.
"""

from __future__ import annotations

from pathlib import Path

import yaml
from mission_builder.mission_builder_worker import MissionBuilderWorker
from mission_tools.mission_constants import (
    get_community_script_files,
    get_optin_community_script_ids,
)
from veaf_libs.mission_template import CATALOG, TIER_NAMES, generate_mission_yaml, tier_modules

ROOT = Path(__file__).resolve().parents[3]

#: The shipped scaffold — the file `prepare` copies when no `--template` is given.
SHIPPED_DEFAULT = ROOT / "src" / "defaults" / "mission-folder" / "mission.yaml"

#: Enumerated from the source of truth rather than hand-listed: a community script added
#: later is covered here without anyone remembering to update this file.
OPT_OUT_IDS = tuple(
    sorted(s["id"] for s in get_community_script_files() if s["id"] not in get_optin_community_script_ids())
)


def _worker_for(tmp_path: Path, name: str, mission_yaml_text: str) -> MissionBuilderWorker:
    """Return a builder worker resolved from *mission_yaml_text*, in its own folder."""
    folder = tmp_path / name
    folder.mkdir(parents=True)
    (folder / "mission.yaml").write_text(mission_yaml_text, encoding="utf-8")
    return MissionBuilderWorker(
        mission_folder=folder,
        output_mission=folder / "out.miz",
        dynamic_mode=None,
    )


def _states(worker: MissionBuilderWorker) -> dict[str, bool]:
    """The effective on/off state of every opt-out community script, as the build sees it."""
    return {script_id: worker._community_enabled(script_id) for script_id in OPT_OUT_IDS}


class TestScaffoldCommunityParity:
    def test_the_two_scaffolds_agree_on_every_opt_out_script(self, tmp_path: Path) -> None:
        """Side by side, tier by tier: what a generated mission ends up with, vs the shipped file.

        A script the tier does not enable must end up exactly where the shipped default puts it.
        A script the tier *does* enable is the one legitimate difference — and it must be on.
        """
        shipped = _states(_worker_for(tmp_path, "shipped", SHIPPED_DEFAULT.read_text(encoding="utf-8")))

        for tier in TIER_NAMES:
            enabled = tier_modules(tier)
            generated = _states(_worker_for(tmp_path, f"tier-{tier}", generate_mission_yaml(enabled)))
            for script_id in OPT_OUT_IDS:
                if script_id.upper() in enabled:
                    assert generated[script_id] is True, f"{tier} lists {script_id}, so it must be on"
                else:
                    assert generated[script_id] == shipped[script_id], (
                        f"--template {tier} and the shipped default disagree on {script_id}: "
                        f"generated={generated[script_id]}, shipped={shipped[script_id]}"
                    )

    def test_a_generated_scaffold_never_leaves_an_opt_out_script_to_omission(self, tmp_path: Path) -> None:
        """The file must *say* what it does: an omission that means "on" cannot be read.

        Covers the tiers and a hand-picked `custom` set — the picker feeds the same generator.
        """
        for enabled in (*(tier_modules(tier) for tier in TIER_NAMES), {"RADIO", "SPAWN"}):
            text = generate_mission_yaml(enabled)
            modules = (yaml.safe_load(text) or {}).get("modules") or {}
            for script_id in OPT_OUT_IDS:
                key = script_id.upper()
                assert key in modules, f"{key} is absent from the generated modules: block, so its state is implicit"
                assert bool(modules[key]) is (key in enabled)

    def test_a_minimal_mission_does_not_carry_ctld(self, tmp_path: Path) -> None:
        """The reported symptom, end to end: no CTLD, hence no warning about its configuration.

        `_ctld_user_config_lua` is what injects CTLD's sidecar and logs "CTLD is enabled but no
        ctld-config.yaml was found" — the message the tutorial's reader was shown.
        """
        worker = _worker_for(tmp_path, "minimal", generate_mission_yaml(tier_modules("minimal")))
        assert worker._community_enabled("ctld") is False
        assert worker._ctld_user_config_lua() is None
        assert worker.enabled_community_script_ids is not None
        assert not set(OPT_OUT_IDS) & worker.enabled_community_script_ids

    def test_the_catalog_marks_exactly_the_opt_out_community_scripts(self) -> None:
        """The "write it even when off" rule is driven by the community-script source of truth.

        Enumerated, not sampled: if a script becomes opt-out (or stops being one) and the catalog
        is not updated, this fails instead of quietly reintroducing the drift.
        """
        marked = {module_id for module_id, module in CATALOG.items() if module.disabled_block}
        assert marked == {script_id.upper() for script_id in OPT_OUT_IDS}

    def test_the_scaffolds_keep_the_ctld_sidecar_hint(self) -> None:
        """The only place a mission maker learns CTLD is configured in a separate file.

        It has to survive in both scaffolds, on or off — losing it while making the flag explicit
        would trade one silent confusion for another.
        """
        shipped = SHIPPED_DEFAULT.read_text(encoding="utf-8")
        for text in (shipped, *(generate_mission_yaml(tier_modules(tier)) for tier in TIER_NAMES)):
            assert "ctld-config.yaml" in text
