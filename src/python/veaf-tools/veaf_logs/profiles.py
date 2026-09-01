"""Profils de configuration.

Un profil est un jeu de filtres nomme : etats des niveaux, des sources et des
familles de bruit, criteres textuels cumules, nombre de lignes de contexte.
Il se choisit dans une liste deroulante, sans passer par un fichier.

Trois profils sont fournis d'office et ne peuvent etre ni modifies ni
supprimes ; ils servent de point de depart et de porte de sortie quand on s'est
perdu dans ses filtres.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from .filters import FilterSet, State

PROFILES_VERSION = 1
DEFAULT_PROFILE = "Session courante"


def default_profiles_path() -> Path:
    base = os.environ.get("APPDATA") or os.path.expanduser("~/.config")
    return Path(base) / "veaf_logs" / "profiles.json"


def builtin_profiles(rules) -> dict[str, FilterSet]:
    """Profils fournis, calcules depuis le catalogue courant."""
    bruit_masque = {family: State.OFF for family in rules.default_hidden_noise()}

    tout = FilterSet()

    lecture = FilterSet(noise=dict(bruit_masque))

    # Ne garder que ce qui reclame une action, en laissant quelques lignes
    # alentour pour comprendre le contexte de l'erreur.
    diagnostic = FilterSet(
        levels={
            "INFO": State.CONTEXT,
            "DEBUG": State.CONTEXT,
            "TRACE": State.CONTEXT,
        },
        noise=dict(bruit_masque),
        context_lines=3,
    )

    return {
        "Tout": tout,
        "Lecture (sans le bruit ED)": lecture,
        "Diagnostic (erreurs + contexte)": diagnostic,
    }


class ProfileStore:
    """Profils fournis et profils de l'utilisateur, dans un meme espace de noms."""

    def __init__(self, rules, path: Path | None = None) -> None:
        self.path = path or default_profiles_path()
        self.builtin = builtin_profiles(rules)
        self.user: dict[str, FilterSet] = {}
        self.load()

    # -- consultation -----------------------------------------------------

    def names(self) -> list[str]:
        """Profils fournis d'abord, puis ceux de l'utilisateur par ordre alphabetique."""
        return list(self.builtin) + sorted(self.user)

    def is_builtin(self, name: str) -> bool:
        return name in self.builtin

    def get(self, name: str) -> FilterSet | None:
        found = self.builtin.get(name) or self.user.get(name)
        # On rend une copie : modifier les filtres courants ne doit pas
        # reecrire le profil dont ils proviennent.
        return found.copy() if found is not None else None

    # -- modification -----------------------------------------------------

    def save_profile(self, name: str, filters: FilterSet) -> None:
        """Enregistre ou remplace un profil utilisateur."""
        name = name.strip()
        if not name:
            raise ValueError("un profil doit avoir un nom")
        if name in self.builtin:
            raise ValueError(f"« {name} » est un profil fourni, choisis un autre nom")
        self.user[name] = filters.copy()
        self.save()

    def delete(self, name: str) -> None:
        if name in self.builtin:
            raise ValueError(f"« {name} » est un profil fourni, il ne peut pas etre supprime")
        self.user.pop(name, None)
        self.save()

    def rename(self, old: str, new: str) -> None:
        if old in self.builtin:
            raise ValueError(f"« {old} » est un profil fourni, il ne peut pas etre renomme")
        filters = self.user.pop(old, None)
        if filters is None:
            return
        self.user[new.strip()] = filters
        self.save()

    # -- persistance ------------------------------------------------------

    def load(self) -> None:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            # Fichier absent ou illisible : on repart des seuls profils fournis
            # plutot que d'empecher le lancement.
            self.user = {}
            return
        if payload.get("version") != PROFILES_VERSION:
            self.user = {}
            return
        self.user = {
            name: FilterSet.from_dict(raw)
            for name, raw in (payload.get("profiles") or {}).items()
            if name not in self.builtin
        }

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": PROFILES_VERSION,
            "profiles": {name: filters.to_dict() for name, filters in self.user.items()},
        }
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        temporary.replace(self.path)
