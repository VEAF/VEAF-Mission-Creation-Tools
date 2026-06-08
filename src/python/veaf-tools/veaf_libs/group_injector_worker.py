"""Abstract base class for workers that iterate over DCS mission groups."""

from abc import abstractmethod
from pathlib import Path
from typing import Any

from mission_tools import DcsMission, Group, read_miz, write_miz

from veaf_libs.base_worker import BaseWorker
from veaf_libs.i18n import t
from veaf_libs.logger import logger
from veaf_libs.progress import spinner_context


class GroupInjectorWorker(BaseWorker):
    """Abstract base worker for injectors that iterate over aircraft/helicopter groups.

    Subclasses implement :meth:`load_config` and :meth:`process_group`.
    :meth:`work` handles the full read → iterate → write pipeline.
    """

    def __init__(
        self,
        config_file: Path | None,
        input_mission: Path | None,
        output_mission: Path | None,
    ) -> None:
        self.config_file = config_file
        self.input_mission = input_mission
        self.output_mission = output_mission
        self.dcs_mission: DcsMission | None = None
        self.load_config()

    @abstractmethod
    def load_config(self) -> Any:
        """Load configuration (from YAML or other source)."""

    @abstractmethod
    def process_group(self, group: Group) -> None:
        """Apply injection logic to a single group (mutates group.group_dcs in place)."""

    def read_mission(self, silent: bool = False) -> None:
        """Load the mission from the .miz file."""
        if not silent:
            logger.info(t("group_injector.reading_mission", path=self.input_mission))
        assert self.input_mission is not None
        self.dcs_mission = read_miz(self.input_mission)

    def write_mission(self, silent: bool = False) -> None:
        """Write the modified mission to output_mission."""
        if not silent:
            logger.info(t("group_injector.writing_mission"))
        assert self.dcs_mission is not None
        write_miz(mission=self.dcs_mission, miz_file_path=self.output_mission)

    def work(self, silent: bool = False) -> Path | None:
        """Read mission, iterate groups, process each, write mission."""
        with spinner_context(t("group_injector.spinner.reading", path=self.input_mission), silent=silent):
            self.read_mission(silent)

        assert self.dcs_mission is not None
        for group in self.dcs_mission.iter_groups():
            self.process_group(group)

        with spinner_context(t("group_injector.spinner.writing"), silent=silent):
            self.write_mission(silent)

        return self.output_mission
