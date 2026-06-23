"""Promote a VEAF mission's exploded ``src/mission/`` from v5 to v6 on disk.

``convert-v5`` converts a mission folder's Lua/config to v6 but leaves the
exploded DCS mission (``src/mission/``) in v5 — the v5→v6 trigger migration is
otherwise re-done in memory on every build (``migrate_from_v5=True``). This
module performs that migration **once, on disk**, via a *base build → extract*
round-trip (FEAT-MIGRATE-MISSION-V6):

1. **base build** — :class:`MissionBuilderWorker` alone clears the legacy v5
   triggers and reinjects the v6 framework triggers/scripts/config, producing a
   temporary ``.miz``. The data injectors (aircraft, waypoints, …) are **not**
   run: the injected data already lives in ``src/mission/`` (the live extract of
   a previously-built ``.miz``) and the base build preserves it — it only ever
   removes VEAF triggers, never groups/routes/units.
2. **backup** — the current ``src/mission/`` is copied to
   ``backup_v5/src/mission/``.
3. **extract** — the temporary ``.miz`` is re-extracted into ``src/mission/``.

The operation is **non-blocking**: a base-build failure leaves ``src/mission/``
untouched; an extract failure restores it from the backup. Either way the
caller is told what happened via :class:`PromotionResult`.
"""

from __future__ import annotations

import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from veaf_libs.i18n import t
from veaf_libs.logger import logger

from mission_builder.mission_builder_worker import MissionBuilderWorker


@dataclass
class PromotionResult:
    """Outcome of a :func:`promote_mission_to_v6` run."""

    promoted: bool
    """``True`` when ``src/mission/`` was successfully rewritten in v6."""

    backup_path: Path | None = None
    """Path to the ``backup_v5/src/mission/`` copy, when one was made."""

    reason: str = ""
    """Human-readable reason the promotion was skipped/failed (empty on success)."""


def promote_mission_to_v6(
    mission_folder: Path,
    version: str = "unknown",
    scripts_path_override: str | Path | None = None,
    silent: bool = False,
) -> PromotionResult:
    """Rewrite ``src/mission/`` from v5 to v6 on disk (non-blocking).

    Args:
        mission_folder: Root of the VEAF mission folder.
        version: Tool version, forwarded to the builder for provenance.
        scripts_path_override: Optional explicit ``published/`` scripts path.
        silent: When ``True``, suppress the sub-workers' progress output.

    Returns:
        A :class:`PromotionResult` describing what happened. ``promoted`` is
        ``False`` (with a ``reason``) when there is nothing to promote, the base
        build fails, or the extract fails — never raising for those cases.
    """
    # Local import avoids a package-load cycle (extractor → mission_tools → …).
    from mission_extractor import MissionExtractorWorker

    src_mission = mission_folder / "src" / "mission"
    if not src_mission.is_dir():
        return PromotionResult(promoted=False, reason=t("promote.no_src_mission", path=src_mission))

    with tempfile.TemporaryDirectory() as tmp:
        temp_miz = Path(tmp) / "promote-build.miz"

        # 1. Base build to a throwaway .miz. Non-blocking: on failure src/mission
        #    is left exactly as it was.
        try:
            MissionBuilderWorker(
                mission_folder=mission_folder,
                output_mission=temp_miz,
                dynamic_mode=None,
                scripts_path_override=scripts_path_override,
                migrate_from_v5=True,
            ).work(silent=silent)
        except Exception as exc:  # noqa: BLE001 - promotion must never abort the caller
            logger.warning(t("promote.build_failed", error=exc))
            return PromotionResult(promoted=False, reason=t("promote.build_failed", error=exc))

        # 2. Back up the current src/mission before overwriting it.
        backup_dest = mission_folder / "backup_v5" / "src" / "mission"
        if backup_dest.exists():
            shutil.rmtree(backup_dest)
        backup_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(src_mission, backup_dest)

        # 3. Replace src/mission with a clean extract of the freshly built .miz.
        #    Remove the old tree first so the extract is a rewrite, not a merge.
        shutil.rmtree(src_mission)
        try:
            MissionExtractorWorker(
                mission_folder=mission_folder,
                input_mission_path=temp_miz,
                refresh=False,
            ).work(silent=silent)
        except Exception as exc:  # noqa: BLE001 - restore the backup, never leave src/mission missing
            if src_mission.exists():
                shutil.rmtree(src_mission)
            shutil.copytree(backup_dest, src_mission)
            logger.warning(t("promote.extract_failed", error=exc))
            return PromotionResult(
                promoted=False, backup_path=backup_dest, reason=t("promote.extract_failed", error=exc)
            )

    logger.info(t("promote.done", backup=backup_dest))
    return PromotionResult(promoted=True, backup_path=backup_dest)
