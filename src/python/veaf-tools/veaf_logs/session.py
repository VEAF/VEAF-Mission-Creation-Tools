"""Sauvegarde et restauration de la session de travail.

Ce qui est conserve : les fichiers ouverts et l'onglet actif, les filtres en
cours, le profil selectionne, la geometrie de la fenetre, la police et la
presence du panneau de detail. La session est ecrite dans le repertoire de
configuration de l'utilisateur, pas dans le depot.

La session retient l'etat *courant*, meme s'il ne correspond a aucun profil
enregistre : on retrouve son travail tel qu'on l'a laisse.

Ajouter un champ ne demande pas de changer `SESSION_VERSION` : `load` ecarte les
cles inconnues et laisse la classe fournir celles qui manquent. Incrementer la
version jetterait les fichiers ouverts et les filtres de tout le monde pour une
taille de police.
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path

from .appearance import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from .filters import FilterSet

SESSION_VERSION = 2


def default_session_path() -> Path:
    """`%APPDATA%\\dcslog\\session.json` sous Windows, `~/.config` ailleurs."""
    base = os.environ.get("APPDATA") or os.path.expanduser("~/.config")
    return Path(base) / "veaf_logs" / "session.json"


@dataclass
class OpenFile:
    path: str
    archive_member: str | None = None


@dataclass
class Session:
    files: list[OpenFile] = field(default_factory=list)
    active: int = 0
    profile: str = ""
    filters: dict = field(default_factory=dict)
    geometry: str | None = None
    font_family: str = DEFAULT_FONT_FAMILY
    font_size: int = DEFAULT_FONT_SIZE
    detail_visible: bool = True

    # -- persistance ------------------------------------------------------

    def save(self, path: Path | None = None) -> Path:
        path = path or default_session_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = asdict(self)
        payload["version"] = SESSION_VERSION
        # Ecriture atomique : une session tronquee par un arret brutal
        # empecherait le demarrage suivant.
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        temporary.replace(path)
        return path

    @classmethod
    def load(cls, path: Path | None = None) -> Session:
        path = path or default_session_path()
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            # Session absente ou illisible : on repart d'une session vierge
            # plutot que d'empecher le lancement.
            return cls()
        if payload.get("version") != SESSION_VERSION:
            # Format d'une autre version : on ne tente pas de le convertir, on
            # repart proprement.
            return cls()
        payload.pop("version", None)
        files = [OpenFile(**item) for item in payload.pop("files", [])]
        known = set(cls.__dataclass_fields__)
        payload = {key: value for key, value in payload.items() if key in known}
        payload.pop("files", None)
        return cls(files=files, **payload)

    # -- conversions ------------------------------------------------------

    def set_filters(self, filters: FilterSet) -> None:
        self.filters = filters.to_dict()

    def get_filters(self) -> FilterSet:
        try:
            return FilterSet.from_dict(self.filters or {})
        except (TypeError, ValueError, AttributeError):
            return FilterSet()

    def existing_files(self) -> list[OpenFile]:
        """Ecarte les fichiers disparus depuis la derniere session."""
        return [item for item in self.files if Path(item.path).exists()]
