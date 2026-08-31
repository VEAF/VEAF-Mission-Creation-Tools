"""Tests des profils et de la session."""

from __future__ import annotations

import json

import pytest
from veaf_logs.filters import FilterSet, Mode, State, TextFilter
from veaf_logs.profiles import PROFILES_VERSION, ProfileStore
from veaf_logs.session import SESSION_VERSION, OpenFile, Session


@pytest.fixture
def profiles(rules, tmp_path) -> ProfileStore:
    return ProfileStore(rules, tmp_path / "profiles.json")


class TestProfilsFournis:
    def test_presents(self, profiles):
        noms = profiles.names()
        assert "Tout" in noms
        assert any("Lecture" in nom for nom in noms)
        assert any("Diagnostic" in nom for nom in noms)

    def test_tout_n_a_aucun_filtre(self, profiles):
        assert profiles.get("Tout").is_empty

    def test_lecture_masque_le_bruit(self, profiles, rules):
        filtres = profiles.get("Lecture (sans le bruit ED)")
        assert filtres.noise["damage_model"] is State.OFF
        assert set(filtres.noise) == rules.default_hidden_noise()

    def test_diagnostic_met_l_info_en_contexte(self, profiles):
        filtres = profiles.get("Diagnostic (erreurs + contexte)")
        assert filtres.levels["INFO"] is State.CONTEXT
        assert filtres.context_lines > 0

    def test_non_modifiables(self, profiles):
        with pytest.raises(ValueError, match="fourni"):
            profiles.save_profile("Tout", FilterSet())
        with pytest.raises(ValueError, match="fourni"):
            profiles.delete("Tout")

    def test_rendus_en_copie(self, profiles):
        """Modifier les filtres courants ne doit pas reecrire le profil."""
        filtres = profiles.get("Tout")
        filtres.levels["INFO"] = State.OFF
        assert profiles.get("Tout").levels == {}


class TestProfilsUtilisateur:
    def test_enregistrer_et_relire(self, profiles, rules, tmp_path):
        filtres = FilterSet(
            levels={"INFO": State.CONTEXT},
            text_filters=[TextFilter(pattern="CSAR", mode=Mode.PLAIN)],
            context_lines=5,
        )
        profiles.save_profile("Mon profil", filtres)

        relu = ProfileStore(rules, tmp_path / "profiles.json")
        recharge = relu.get("Mon profil")
        assert recharge.levels == {"INFO": State.CONTEXT}
        assert recharge.text_filters[0].pattern == "CSAR"
        assert recharge.context_lines == 5

    def test_remplacer(self, profiles):
        profiles.save_profile("P", FilterSet(context_lines=1))
        profiles.save_profile("P", FilterSet(context_lines=9))
        assert profiles.get("P").context_lines == 9

    def test_supprimer(self, profiles):
        profiles.save_profile("P", FilterSet())
        profiles.delete("P")
        assert profiles.get("P") is None

    def test_renommer(self, profiles):
        profiles.save_profile("Avant", FilterSet(context_lines=4))
        profiles.rename("Avant", "Apres")
        assert profiles.get("Avant") is None
        assert profiles.get("Apres").context_lines == 4

    def test_nom_vide_refuse(self, profiles):
        with pytest.raises(ValueError):
            profiles.save_profile("   ", FilterSet())

    def test_nom_normalise(self, profiles):
        profiles.save_profile("  espace  ", FilterSet())
        assert profiles.get("espace") is not None

    def test_ordre(self, profiles):
        """Les profils fournis d'abord, les autres par ordre alphabetique."""
        profiles.save_profile("Zeta", FilterSet())
        profiles.save_profile("Alpha", FilterSet())
        noms = profiles.names()
        assert noms[:3] == list(profiles.builtin)
        assert noms[3:] == ["Alpha", "Zeta"]

    def test_fichier_illisible(self, rules, tmp_path):
        path = tmp_path / "profiles.json"
        path.write_text("{ pas du json", encoding="utf-8")
        assert ProfileStore(rules, path).user == {}

    def test_version_incompatible(self, rules, tmp_path):
        path = tmp_path / "profiles.json"
        path.write_text(json.dumps({"version": PROFILES_VERSION + 1, "profiles": {"X": {}}}), encoding="utf-8")
        assert ProfileStore(rules, path).user == {}


class TestSession:
    def test_aller_retour(self, tmp_path):
        path = tmp_path / "session.json"
        session = Session(
            files=[OpenFile("C:/dcs.log"), OpenFile("C:/a.zip", "dcs.log")],
            active=1,
            profile="Mon profil",
        )
        session.set_filters(
            FilterSet(
                levels={"INFO": State.CONTEXT},
                text_filters=[TextFilter(pattern="x", invert=True)],
                context_lines=4,
            )
        )
        session.save(path)

        relue = Session.load(path)
        assert relue.active == 1
        assert relue.profile == "Mon profil"
        assert relue.files[1].archive_member == "dcs.log"
        filtres = relue.get_filters()
        assert filtres.levels == {"INFO": State.CONTEXT}
        assert filtres.context_lines == 4
        assert filtres.text_filters[0].invert

    def test_session_absente(self, tmp_path):
        assert Session.load(tmp_path / "rien.json").files == []

    def test_session_illisible(self, tmp_path):
        path = tmp_path / "session.json"
        path.write_text("{ pas du json", encoding="utf-8")
        assert Session.load(path).files == []

    def test_version_incompatible(self, tmp_path):
        path = tmp_path / "session.json"
        path.write_text(json.dumps({"version": SESSION_VERSION + 1, "active": 3}), encoding="utf-8")
        assert Session.load(path).active == 0

    def test_champ_inconnu_ignore(self, tmp_path):
        path = tmp_path / "session.json"
        path.write_text(
            json.dumps({"version": SESSION_VERSION, "active": 2, "nouveaute": 42}),
            encoding="utf-8",
        )
        assert Session.load(path).active == 2

    def test_filtres_corrompus(self, tmp_path):
        path = tmp_path / "session.json"
        path.write_text(json.dumps({"version": SESSION_VERSION, "filters": "pas un objet"}), encoding="utf-8")
        assert Session.load(path).get_filters().is_empty

    def test_fichiers_disparus_ecartes(self, tmp_path):
        present = tmp_path / "present.log"
        present.write_text("x", encoding="utf-8")
        session = Session(files=[OpenFile(str(present)), OpenFile(str(tmp_path / "parti.log"))])
        assert [item.path for item in session.existing_files()] == [str(present)]

    def test_ecriture_atomique(self, tmp_path):
        path = tmp_path / "session.json"
        Session(active=1).save(path)
        assert not path.with_suffix(".tmp").exists()
        assert Session.load(path).active == 1
