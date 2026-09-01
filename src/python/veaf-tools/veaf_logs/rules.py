"""Chargement et application du catalogue de regles (`rules.json`).

Le catalogue est la source unique : `store` en tire les motifs qui classent
chaque ligne, l'interface les couleurs et les libelles. Le modifier n'exige
aucune modification de code.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

DEFAULT_RULES_PATH = Path(__file__).with_name("rules.json")

LEVEL_NAMES = frozenset(("ALERT", "ERROR", "ERROR_ONCE", "WARNING", "INFO", "DEBUG", "TRACE", "UNKNOWN"))

# Couleur de repli pour un sous-systeme DCS natif, qui n'est pas dans `sources`.
NATIVE_SOURCE = "dcs"
NATIVE_LABEL = "DCS"
NATIVE_COLOR = "#8b949e"


@dataclass(slots=True)
class Source:
    id: str
    label: str
    color: str
    pattern: re.Pattern
    level_group: str | int | None = None
    level_map: dict[str, str] | None = None
    module_pattern: re.Pattern | None = None


@dataclass(slots=True)
class NoiseFamily:
    id: str
    label: str
    help: str
    pattern: re.Pattern
    default_hidden: bool
    on_message: bool  # tester le message seul plutot que la ligne entiere


@dataclass(slots=True)
class LevelStyle:
    color: str
    background: str | None
    weight: int
    order: int


class Rules:
    """Catalogue charge, avec ses expressions deja compilees."""

    def __init__(self, data: dict) -> None:
        self._data = data
        self.sources: list[Source] = []
        self.noise: list[NoiseFamily] = []
        self.levels: dict[str, LevelStyle] = {}
        self.subsystem_families: dict[str, list[str]] = {}
        self._compile()

    # -- chargement -------------------------------------------------------

    @classmethod
    def load(cls, path: Path | str | None = None) -> Rules:
        path = Path(path) if path else DEFAULT_RULES_PATH
        with open(path, encoding="utf-8") as handle:
            return cls(json.load(handle))

    def _compile(self) -> None:
        for raw in self._data.get("sources", []):
            module = raw.get("module_pattern")
            self.sources.append(
                Source(
                    id=raw["id"],
                    label=raw["label"],
                    color=raw["color"],
                    pattern=re.compile(raw["match"]),
                    level_group=raw.get("level_group"),
                    level_map=raw.get("level_map"),
                    module_pattern=re.compile(module) if module else None,
                )
            )

        for raw in self._data.get("noise", []):
            pattern = raw["match"] if raw.get("regex", True) else re.escape(raw["match"])
            self.noise.append(
                NoiseFamily(
                    id=raw["id"],
                    label=raw["label"],
                    help=raw.get("help", ""),
                    pattern=re.compile(pattern),
                    default_hidden=bool(raw.get("default_hidden", False)),
                    on_message=bool(raw.get("on_message", False)),
                )
            )

        for name, raw in self._data.get("levels", {}).items():
            self.levels[name] = LevelStyle(
                color=raw["color"],
                background=raw.get("background"),
                weight=int(raw.get("weight", 400)),
                order=int(raw.get("order", 99)),
            )

        self.subsystem_families = {
            key: value for key, value in self._data.get("subsystem_families", {}).items() if not key.startswith("$")
        }

    # -- acces ------------------------------------------------------------

    def source_color(self, source_id: str) -> str:
        for source in self.sources:
            if source.id == source_id:
                return source.color
        return NATIVE_COLOR

    def level_style(self, level: str) -> LevelStyle:
        return self.levels.get(level) or LevelStyle(NATIVE_COLOR, None, 400, 99)

    def level_order(self, level: str) -> int:
        return self.level_style(level).order

    def default_hidden_noise(self) -> set[str]:
        return {family.id for family in self.noise if family.default_hidden}

    def source_labels(self) -> dict[str, str]:
        labels = {source.id: source.label for source in self.sources}
        labels[NATIVE_SOURCE] = NATIVE_LABEL
        return labels

    @property
    def data(self) -> dict:
        return self._data
