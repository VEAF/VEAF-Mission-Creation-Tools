"""Tests du miroir SFTP et de la source distante, contre un faux client.

Le faux client sert un fichier local : ce que DCS ecrit sur le serveur, le
test l'ecrit dans `tmp_path`. Aucune connexion reseau ici ; le contrat avec
paramiko (`stat`, `open`, `seek`, `read`) est celui que `SftpClient` declare.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from veaf_libs.user_config import RemoteServer
from veaf_logs.remote import (
    RemoteFileMissing,
    RemoteLogSource,
    SftpMirrorBuffer,
    accept_host_key,
    host_key_fingerprint,
    remember_host_key,
    sftp_path,
)
from veaf_logs.tailer import LogUnavailable

LIGNE = "2026-09-24 19:0{n}:00.000 INFO    APP (Main): message {n}\n"


class FakeSftp:
    """Un client SFTP qui sert un fichier local, et qu'on peut faire tomber."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.down = False
        self.calls: list[str] = []

    def stat(self, path: str) -> os.stat_result:
        self.calls.append("stat")
        if self.down:
            raise EOFError("connexion perdue")
        return os.stat(self.path)

    def open(self, path: str, mode: str = "r"):
        self.calls.append("open")
        if self.down:
            raise EOFError("connexion perdue")
        return open(self.path, "rb")


@pytest.fixture
def remote(tmp_path: Path) -> Path:
    path = tmp_path / "remote.log"
    path.write_bytes((LIGNE.format(n=0)).encode())
    return path


@pytest.fixture
def sftp(remote: Path) -> FakeSftp:
    return FakeSftp(remote)


@pytest.fixture
def mirror(sftp: FakeSftp, tmp_path: Path):
    buffer = SftpMirrorBuffer(sftp, "/C:/remote.log", mirror_dir=tmp_path)
    yield buffer
    buffer.close()


def _append(path: Path, n: int) -> None:
    # En octets : en mode texte, Windows ecrirait CR LF et les tailles ne
    # correspondraient plus a ce que le test calcule.
    with open(path, "ab") as handle:
        handle.write(LIGNE.format(n=n).encode())


class TestMiroir:
    def test_premier_sync_copie_tout(self, mirror: SftpMirrorBuffer, remote: Path):
        assert mirror.sync() is False
        assert mirror.size() == remote.stat().st_size
        assert mirror.slice(0, mirror.size()) == remote.read_bytes()

    def test_sync_suivant_ne_rapatrie_que_le_delta(self, mirror: SftpMirrorBuffer, remote: Path, sftp: FakeSftp):
        mirror.sync()
        before = mirror.size()
        _append(remote, 1)
        sftp.calls.clear()
        assert mirror.sync() is False
        assert mirror.size() == remote.stat().st_size
        assert mirror.slice(before, mirror.size() - before) == LIGNE.format(n=1).encode()
        assert mirror.slice(0, mirror.size()) == remote.read_bytes()

    def test_sans_changement_un_seul_stat(self, mirror: SftpMirrorBuffer, sftp: FakeSftp):
        mirror.sync()
        sftp.calls.clear()
        mirror.sync()
        assert sftp.calls == ["stat"]

    def test_refresh_ne_touche_pas_le_reseau(self, mirror: SftpMirrorBuffer, sftp: FakeSftp, remote: Path):
        mirror.sync()
        _append(remote, 1)
        sftp.calls.clear()
        assert mirror.refresh() == mirror.size()
        assert sftp.calls == []

    def test_rotation_par_taille(self, mirror: SftpMirrorBuffer, remote: Path):
        _append(remote, 1)
        _append(remote, 2)
        mirror.sync()
        # DCS redemarre : journal neuf, plus court.
        remote.write_bytes((LIGNE.format(n=9)).encode())
        assert mirror.sync() is True
        assert mirror.slice(0, mirror.size()) == remote.read_bytes()

    def test_rotation_par_entete(self, mirror: SftpMirrorBuffer, remote: Path):
        mirror.sync()
        # Journal neuf, deja plus long que l'ancien : seule l'entete le trahit.
        remote.write_bytes((LIGNE.format(n=5) + LIGNE.format(n=6)).encode())
        assert mirror.sync() is True
        assert mirror.slice(0, mirror.size()) == remote.read_bytes()

    def test_coupure_puis_reprise(self, mirror: SftpMirrorBuffer, sftp: FakeSftp, remote: Path):
        mirror.sync()
        sftp.down = True
        _append(remote, 1)
        with pytest.raises(LogUnavailable):
            mirror.sync()
        # Le miroir n'a rien perdu.
        assert mirror.size() == len(LIGNE.format(n=0))
        sftp.down = False
        assert mirror.sync() is False
        assert mirror.slice(0, mirror.size()) == remote.read_bytes()

    def test_fichier_absent(self, mirror: SftpMirrorBuffer, remote: Path):
        remote.unlink()
        with pytest.raises(RemoteFileMissing):
            mirror.sync()

    def test_close_supprime_le_miroir(self, sftp: FakeSftp, tmp_path: Path):
        buffer = SftpMirrorBuffer(sftp, "/C:/remote.log", mirror_dir=tmp_path)
        buffer.sync()
        assert buffer.path.exists()
        buffer.close()
        assert not buffer.path.exists()
        buffer.close()  # idempotent


class TestCheminSftp:
    @pytest.mark.parametrize(
        ("given", "expected"),
        [
            ("C:/Users/veaf/Saved Games/x/Logs/dcs.log", "/C:/Users/veaf/Saved Games/x/Logs/dcs.log"),
            ("C:\\Users\\veaf\\dcs.log", "/C:/Users/veaf/dcs.log"),
            ("/C:/Users/veaf/dcs.log", "/C:/Users/veaf/dcs.log"),
            ("/home/dcs/dcs.log", "/home/dcs/dcs.log"),
        ],
    )
    def test_forme_sftp(self, given: str, expected: str):
        assert sftp_path(given) == expected


class FakeKey:
    def get_name(self) -> str:
        return "ssh-ed25519"

    def get_base64(self) -> str:
        return "AAAAC3NzaC1lZDI1NTE5AAAAIFAKE"

    def asbytes(self) -> bytes:
        return b"fake-key-bytes"


class TestCleDHote:
    def test_empreinte_forme_openssh(self):
        fingerprint = host_key_fingerprint(FakeKey())
        assert fingerprint.startswith("SHA256:")
        assert "=" not in fingerprint

    def test_memoriser_ajoute_sans_ecraser(self, tmp_path: Path):
        known = tmp_path / ".ssh" / "known_hosts"
        known.parent.mkdir()
        known.write_text("autre ssh-rsa AAAA\n", encoding="utf-8")
        remember_host_key(known, "[dcs.veaf.org]:2222", FakeKey())
        assert known.read_text(encoding="utf-8").splitlines() == [
            "autre ssh-rsa AAAA",
            "[dcs.veaf.org]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAKE",
        ]

    def test_memoriser_cree_le_fichier(self, tmp_path: Path):
        known = tmp_path / ".ssh" / "known_hosts"
        remember_host_key(known, "dcs.veaf.org", FakeKey())
        assert known.read_text(encoding="utf-8").startswith("dcs.veaf.org ssh-ed25519 ")


def _server(remote: Path) -> RemoteServer:
    return RemoteServer(
        name="veaf",
        host="dcs.veaf.org",
        user="veaf",
        logs={"private1": "C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log"},
    )


class FakeSsh:
    def __init__(self) -> None:
        self.closed = False

    def close(self) -> None:
        self.closed = True


class Connector:
    """Fabrique de connexions injectee dans `RemoteLogSource`."""

    def __init__(self, sftp: FakeSftp) -> None:
        self.sftp = sftp
        self.clients: list[FakeSsh] = []
        self.fail = False

    def __call__(self, server: RemoteServer, prompt):
        if self.fail:
            raise ConnectionError("injoignable")
        client = FakeSsh()
        self.clients.append(client)
        return client, self.sftp


@pytest.fixture
def connector(sftp: FakeSftp) -> Connector:
    return Connector(sftp)


@pytest.fixture
def source(remote: Path, connector: Connector, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setattr("tempfile.tempdir", str(tmp_path))
    source = RemoteLogSource(_server(remote), "private1", connect=connector)
    yield source
    source.close()


class TestSourceDistante:
    def test_identite(self, source: RemoteLogSource):
        assert source.remote == "veaf/private1"
        assert source.display_name == "veaf:private1"
        assert source.location == "veaf@dcs.veaf.org:C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log"
        assert source.followable
        assert source.poll_interval > 0

    def test_instance_inconnue(self, remote: Path):
        with pytest.raises(KeyError):
            RemoteLogSource(_server(remote), "public9")

    def test_open_se_connecte_et_remplit(self, source: RemoteLogSource, connector: Connector, remote: Path):
        buffer = source.open()
        assert len(connector.clients) == 1
        assert buffer.slice(0, buffer.size()) == remote.read_bytes()
        assert isinstance(buffer, SftpMirrorBuffer)
        assert buffer.remote_path == "/C:/Users/veaf/Saved Games/private1_server/Logs/dcs.log"

    def test_check_rotation_rapatrie_puis_signale(self, source: RemoteLogSource, remote: Path):
        source.open()
        indexed = source.buffer.size()
        _append(remote, 1)
        assert source.check_rotation(indexed) is False
        assert source.buffer.size() > indexed
        remote.write_bytes((LIGNE.format(n=9)).encode())
        assert source.check_rotation(indexed) is True
        # Le miroir est deja reparti de zero : `reopen` rend le meme tampon.
        buffer = source.reopen()
        assert buffer is source.buffer
        assert buffer.slice(0, buffer.size()) == remote.read_bytes()

    def test_coupure_ferme_la_connexion_et_retente_apres_delai(
        self, source: RemoteLogSource, connector: Connector, sftp: FakeSftp, monkeypatch: pytest.MonkeyPatch
    ):
        source.open()
        sftp.down = True
        with pytest.raises(LogUnavailable):
            source.check_rotation(0)
        assert connector.clients[0].closed
        sftp.down = False
        # Trop tot : pas de nouvelle connexion.
        with pytest.raises(LogUnavailable, match="nouvelle tentative"):
            source.check_rotation(0)
        assert len(connector.clients) == 1
        # Delai ecoule : reconnexion, le miroir reprend ou il en etait.
        monkeypatch.setattr("veaf_logs.remote.time.monotonic", lambda: 1e9)
        assert source.check_rotation(0) is False
        assert len(connector.clients) == 2

    def test_fichier_absent_garde_la_connexion(self, source: RemoteLogSource, connector: Connector, remote: Path):
        source.open()
        remote.unlink()
        with pytest.raises(RemoteFileMissing):
            source.check_rotation(0)
        assert not connector.clients[0].closed
        remote.write_bytes((LIGNE.format(n=0)).encode())
        assert source.check_rotation(0) is False
        assert len(connector.clients) == 1

    def test_connexion_impossible(self, source: RemoteLogSource, connector: Connector):
        connector.fail = True
        with pytest.raises(LogUnavailable, match="injoignable"):
            source.open()

    def test_close_libere_tout(self, source: RemoteLogSource, connector: Connector):
        buffer = source.open()
        assert isinstance(buffer, SftpMirrorBuffer)
        source.close()
        assert connector.clients[0].closed
        assert not buffer.path.exists()


class TestDecisionCleDHote:
    def _key(self):
        return FakeKey()

    def test_acceptee_et_memorisee(self, tmp_path: Path):
        known = tmp_path / "known_hosts"
        asked: list[tuple[str, str]] = []

        def prompt(hostname: str, fingerprint: str) -> bool:
            asked.append((hostname, fingerprint))
            return True

        accept_host_key(prompt, known, "dcs.veaf.org", self._key())
        assert asked[0][0] == "dcs.veaf.org"
        assert asked[0][1].startswith("ssh-ed25519 SHA256:")
        assert known.read_text(encoding="utf-8").startswith("dcs.veaf.org ssh-ed25519 ")

    def test_refusee_rien_n_est_ecrit(self, tmp_path: Path):
        known = tmp_path / "known_hosts"
        with pytest.raises(ValueError, match="refusee"):
            accept_host_key(lambda hostname, fingerprint: False, known, "dcs.veaf.org", self._key())
        assert not known.exists()

    def test_sans_interface_on_refuse(self, tmp_path: Path):
        known = tmp_path / "known_hosts"
        with pytest.raises(ValueError):
            accept_host_key(None, known, "dcs.veaf.org", self._key())
        assert not known.exists()


class TestSourceDistanteChemins:
    """Les chemins moins frequentes de `RemoteLogSource`."""

    def test_buffer_ouvre_a_la_demande(self, source: RemoteLogSource, connector: Connector):
        buffer = source.buffer
        assert len(connector.clients) == 1
        assert buffer is source.buffer, "le second acces ne rouvre rien"

    def test_check_rotation_avant_open(self, source: RemoteLogSource, remote: Path):
        assert source.check_rotation(0) is False
        assert source.buffer.size() == remote.stat().st_size

    def test_open_apres_coupure_rattache_le_nouveau_client(
        self, source: RemoteLogSource, connector: Connector, sftp: FakeSftp, monkeypatch: pytest.MonkeyPatch
    ):
        buffer = source.open()
        sftp.down = True
        with pytest.raises(LogUnavailable):
            source.check_rotation(0)
        sftp.down = False
        replacement = FakeSftp(sftp.path)
        connector.sftp = replacement
        monkeypatch.setattr("veaf_logs.remote.time.monotonic", lambda: 1e9)
        assert source.open() is buffer, "le miroir survit a la reconnexion"
        assert isinstance(buffer, SftpMirrorBuffer)
        assert buffer.sftp is replacement

    def test_open_sur_fichier_absent_garde_la_connexion(
        self, source: RemoteLogSource, connector: Connector, remote: Path
    ):
        remote.unlink()
        with pytest.raises(RemoteFileMissing):
            source.open()
        assert not connector.clients[0].closed

    def test_open_sur_coupure_ferme_la_connexion(self, source: RemoteLogSource, connector: Connector, sftp: FakeSftp):
        sftp.down = True
        with pytest.raises(LogUnavailable):
            source.open()
        assert connector.clients[0].closed

    def test_close_tolere_un_client_qui_refuse_de_fermer(self, remote: Path, tmp_path: Path, monkeypatch):
        monkeypatch.setattr("tempfile.tempdir", str(tmp_path))

        class Grumpy:
            def close(self) -> None:
                raise RuntimeError("deja ferme")

        source = RemoteLogSource(_server(remote), "private1", connect=lambda s, p: (Grumpy(), FakeSftp(remote)))
        source.open()
        source.close()  # ne leve pas
