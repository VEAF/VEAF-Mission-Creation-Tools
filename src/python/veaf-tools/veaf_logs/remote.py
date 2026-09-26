"""Journal d'un serveur distant, suivi par SFTP.

Le visualiseur lit ses octets par decalage (voir `buffer.py`) : a chaque ligne
affichee, une lecture. Faire un aller-retour reseau par ligne serait intenable,
et le flux d'un `tail -f` distant ne permettrait pas de relire un decalage
donne. D'ou le miroir : `sync()` fait un `stat` distant et rapatrie ce qui a ete
ecrit depuis dans un fichier temporaire local ; `slice()` lit ce fichier. Un
seul echange reseau par sondage, des lectures locales partout ailleurs.

La rotation se detecte comme pour un fichier local : le journal a raccourci,
ou ses premiers octets ne sont plus les memes. Le miroir repart alors de zero
et `check_rotation` le signale a l'onglet, qui vide son index.

Aucun mot de passe ne transite ici : la connexion se fait par cle (celle de la
configuration, sinon l'agent SSH et les cles par defaut de `~/.ssh`).
"""

from __future__ import annotations

import base64
import hashlib
import os
import re
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any, Protocol

from veaf_libs.user_config import RemoteServer

from .buffer import Buffer
from .tailer import _HEAD_BYTES, LogUnavailable

# Taille des lectures SFTP. paramiko decoupe lui-meme en paquets ; une demande
# plus grosse ne fait qu'eviter des allers-retours.
_READ_CHUNK = 1 << 20

# Apres un echec reseau, on ne retente pas a chaque sondage : une connexion SSH
# qui echoue peut prendre plusieurs secondes a le dire.
_RETRY_DELAY_S = 5.0

# Delai de chaque etape de la connexion. Elle se fait sur le fil de
# l'interface : un serveur injoignable ne doit pas la figer plus longtemps que
# ca. Mesure sur dcs.veaf.org le 2026-09-24 : 0,44 s de bout en bout.
_CONNECT_TIMEOUT_S = 5.0

# Un journal local est sonde toutes les 400 ms ; a distance, chaque sondage est
# un echange reseau, une fois par seconde suffit.
REMOTE_POLL_INTERVAL_S = 1.0

HostKeyPrompt = Callable[[str, str], bool]


class RemoteFileMissing(LogUnavailable):
    """Le serveur repond mais le journal n'y est pas (instance arretee).

    Distingue d'une coupure : inutile de refaire la connexion SSH toutes les
    cinq secondes pour un fichier qui reviendra quand l'instance redemarrera.
    """


class SftpFile(Protocol):
    """Ce qu'on demande a un fichier SFTP ouvert (`paramiko.SFTPFile`)."""

    def seek(self, offset: int) -> Any: ...

    def read(self, size: int = -1) -> bytes: ...

    def close(self) -> None: ...


class SftpClient(Protocol):
    """Ce qu'on demande au client SFTP (`paramiko.SFTPClient`)."""

    def stat(self, path: str) -> Any: ...

    def open(self, path: str, mode: str = "r") -> SftpFile: ...


class SftpMirrorBuffer(Buffer):
    """Copie locale d'un fichier distant, prolongee a chaque `sync()`."""

    def __init__(self, sftp: SftpClient, remote_path: str, *, mirror_dir: Path | None = None) -> None:
        self.sftp = sftp
        self.remote_path = remote_path
        descriptor, name = tempfile.mkstemp(prefix="veaf-logs-", suffix=".log", dir=mirror_dir)
        os.close(descriptor)
        self.path = Path(name)
        self._size = 0
        self._head = b""

    # -- Buffer -----------------------------------------------------------

    def size(self) -> int:
        return self._size

    def slice(self, start: int, length: int) -> bytes:
        if length <= 0:
            return b""
        try:
            with open(self.path, "rb") as handle:
                handle.seek(start)
                return handle.read(length)
        except OSError:
            return b""

    def refresh(self) -> int:
        """Rend la taille du miroir. Le reseau n'est touche que par `sync()`.

        `LogStore.index_new` appelle `refresh` a chaque passage ; le garder
        local evite un second echange par sondage et une erreur reseau hors
        de portee du `LogUnavailable` que l'onglet sait attendre.
        """
        return self._size

    def close(self) -> None:
        try:
            self.path.unlink()
        except OSError:
            pass

    # -- reseau -----------------------------------------------------------

    def sync(self) -> bool:
        """Rapatrie ce qui a ete ecrit depuis. Rend True si le fichier a ete remplace.

        Raises:
            LogUnavailable: le serveur ou le fichier ne repond pas. Tout echec
                du client SFTP est ramene a cet etat : du point de vue de
                l'onglet, le journal est momentanement indisponible, et il
                reessaiera au sondage suivant.
        """
        try:
            remote_size = int(self.sftp.stat(self.remote_path).st_size)
            if remote_size == self._size and self._size > 0:
                return False
            handle = self.sftp.open(self.remote_path, "rb")
            try:
                handle.seek(0)
                head = handle.read(_HEAD_BYTES)
                rotated = remote_size < self._size or self._head_changed(head)
                if rotated:
                    self._reset()
                if remote_size > self._size:
                    handle.seek(self._size)
                    self._append(handle, remote_size - self._size)
            finally:
                handle.close()
        except FileNotFoundError as exc:
            raise RemoteFileMissing(f"{self.remote_path} : absent sur le serveur") from exc
        except Exception as exc:  # noqa: BLE001 — frontiere avec le client reseau, voir la docstring
            raise LogUnavailable(f"{self.remote_path} : {exc}") from exc
        self._head = self.slice(0, _HEAD_BYTES)
        return rotated

    def _append(self, handle: SftpFile, wanted: int) -> None:
        with open(self.path, "ab") as mirror:
            while wanted > 0:
                data = handle.read(min(_READ_CHUNK, wanted))
                if not data:
                    # Le fichier est plus court que son `stat` ne l'annoncait :
                    # le reste viendra au prochain passage.
                    break
                mirror.write(data)
                self._size += len(data)
                wanted -= len(data)

    def _reset(self) -> None:
        with open(self.path, "wb"):
            pass
        self._size = 0
        self._head = b""

    def _head_changed(self, head: bytes) -> bool:
        common = min(len(head), len(self._head))
        return head[:common] != self._head[:common]


def sftp_path(path: str) -> str:
    """Forme SFTP d'un chemin Windows : `C:\\x\\y` devient `/C:/x/y`."""
    normalized = path.replace("\\", "/")
    if re.match(r"^[A-Za-z]:", normalized):
        return "/" + normalized
    return normalized


def host_key_fingerprint(key: Any) -> str:
    """Empreinte SHA256 d'une cle d'hote, dans la forme qu'affiche OpenSSH."""
    digest = hashlib.sha256(key.asbytes()).digest()
    return "SHA256:" + base64.b64encode(digest).decode("ascii").rstrip("=")


def remember_host_key(known_hosts: Path, hostname: str, key: Any) -> None:
    """Ajoute une cle d'hote a `known_hosts`, sans toucher au reste du fichier.

    `SSHClient.save_host_keys` reecrirait le fichier avec les seules cles que
    paramiko a ajoutees, et effacerait celles d'OpenSSH. On ajoute une ligne.
    """
    known_hosts.parent.mkdir(parents=True, exist_ok=True)
    with open(known_hosts, "a", encoding="utf-8") as handle:
        handle.write(f"{hostname} {key.get_name()} {key.get_base64()}\n")


def accept_host_key(prompt: HostKeyPrompt | None, known_hosts: Path, hostname: str, key: Any) -> None:
    """Cle d'hote inconnue : demande, memorise si oui, refuse sinon.

    Sans `prompt` (pas d'interface), on refuse : accepter en silence
    reviendrait a ne pas verifier l'hote du tout.

    Raises:
        ValueError: la cle est refusee ; la connexion ne doit pas se faire.
    """
    fingerprint = f"{key.get_name()} {host_key_fingerprint(key)}"
    if prompt is None or not prompt(hostname, fingerprint):
        raise ValueError(f"cle d'hote de {hostname} refusee ({fingerprint})")
    remember_host_key(known_hosts, hostname, key)


def _connect(server: RemoteServer, prompt: HostKeyPrompt | None) -> tuple[Any, SftpClient]:
    """Ouvre la connexion SSH et son canal SFTP. Par cle uniquement."""
    import paramiko

    known_hosts = Path.home() / ".ssh" / "known_hosts"

    class AskPolicy(paramiko.MissingHostKeyPolicy):
        def missing_host_key(self, client: Any, hostname: str, key: Any) -> None:
            try:
                accept_host_key(prompt, known_hosts, hostname, key)
            except ValueError as exc:
                raise paramiko.SSHException(str(exc)) from exc

    client = paramiko.SSHClient()
    if known_hosts.exists():
        client.load_host_keys(str(known_hosts))
    client.set_missing_host_key_policy(AskPolicy())
    client.connect(
        server.host,
        port=server.port,
        username=server.user,
        key_filename=str(server.key) if server.key else None,
        allow_agent=True,
        look_for_keys=True,
        # Les trois delais bornent chaque etape : TCP, banniere SSH, puis
        # authentification. Sans les deux derniers, un hote qui accepte la
        # connexion et se tait figerait l'interface bien plus longtemps.
        timeout=_CONNECT_TIMEOUT_S,
        banner_timeout=_CONNECT_TIMEOUT_S,
        auth_timeout=_CONNECT_TIMEOUT_S,
    )
    try:
        return client, client.open_sftp()
    except Exception:
        # Le sous-systeme SFTP a refuse : ne pas laisser la session SSH ouverte.
        client.close()
        raise


class RemoteLogSource:
    """Un journal distant : meme contrat que `LogSource`, octets via SFTP.

    La connexion s'ouvre au premier `open()` et se rouvre d'elle-meme apres
    une coupure, avec un delai entre deux tentatives.
    """

    archive_member = None
    is_archive = False
    followable = True
    poll_interval = REMOTE_POLL_INTERVAL_S

    def __init__(
        self,
        server: RemoteServer,
        instance: str,
        *,
        host_key_prompt: HostKeyPrompt | None = None,
        connect: Callable[[RemoteServer, HostKeyPrompt | None], tuple[Any, SftpClient]] = _connect,
    ) -> None:
        if instance not in server.logs:
            raise KeyError(f"{server.name} n'a pas d'instance {instance}")
        self.server = server
        self.instance = instance
        self.path = server.logs[instance]
        self._prompt = host_key_prompt
        self._connect = connect
        self._client: Any = None
        self._sftp: SftpClient | None = None
        self._buffer: SftpMirrorBuffer | None = None
        self._retry_after = 0.0

    # -- identite ---------------------------------------------------------

    @property
    def remote(self) -> str:
        """Identifiant `serveur/instance`, tel que la session le retient."""
        return f"{self.server.name}/{self.instance}"

    @property
    def display_name(self) -> str:
        return f"{self.server.name}:{self.instance}"

    @property
    def location(self) -> str:
        return f"{self.server.user}@{self.server.host}:{self.path}"

    # -- ouverture --------------------------------------------------------

    def open(self) -> Buffer:
        """Se connecte si besoin, cree le miroir et le remplit."""
        sftp = self._ensure_connected()
        if self._buffer is None:
            self._buffer = SftpMirrorBuffer(sftp, sftp_path(self.path))
        else:
            # Reconnexion : le miroir survit, le client qu'il tenait est mort.
            self._buffer.sftp = sftp
        try:
            self._buffer.sync()
        except RemoteFileMissing:
            raise
        except LogUnavailable:
            self._drop_connection()
            raise
        return self._buffer

    @property
    def buffer(self) -> Buffer:
        if self._buffer is None:
            return self.open()
        return self._buffer

    def close(self) -> None:
        if self._buffer is not None:
            self._buffer.close()
            self._buffer = None
        self._drop_connection()

    # -- etat -------------------------------------------------------------

    def check_rotation(self, indexed: int) -> bool:
        """Rapatrie les nouveaux octets ; True si le journal a ete remplace.

        Raises:
            LogUnavailable: coupure reseau, ou delai de reconnexion pas ecoule.
        """
        if self._buffer is None:
            self.open()
            return False
        if self._sftp is None:
            # Coupure au passage precedent : le miroir survit, on se
            # reconnecte et on reprend la ou il en etait.
            self._buffer.sftp = self._ensure_connected()
        try:
            rotated = self._buffer.sync()
        except RemoteFileMissing:
            raise
        except LogUnavailable:
            self._drop_connection()
            raise
        return rotated or self._buffer.size() < indexed

    def reopen(self) -> Buffer:
        """Apres une rotation : le miroir est deja reparti de zero dans `sync()`."""
        return self.buffer

    # -- interne ----------------------------------------------------------

    def _ensure_connected(self) -> SftpClient:
        if self._sftp is not None:
            return self._sftp
        now = time.monotonic()
        if now < self._retry_after:
            raise LogUnavailable(f"{self.location} : nouvelle tentative dans {self._retry_after - now:.0f} s")
        try:
            self._client, self._sftp = self._connect(self.server, self._prompt)
        except Exception as exc:  # noqa: BLE001 — frontiere avec le client reseau
            self._retry_after = now + _RETRY_DELAY_S
            raise LogUnavailable(f"{self.location} : {exc}") from exc
        return self._sftp

    def _drop_connection(self) -> None:
        self._sftp = None
        if self._client is not None:
            try:
                self._client.close()
            except Exception:  # noqa: BLE001 — on ferme ce qu'on peut, la connexion est deja perdue
                pass
            self._client = None
        self._retry_after = time.monotonic() + _RETRY_DELAY_S
