"""
This module provides classes for reading and writing missions to and from .miz files.
"""

import contextlib
import io
import os
import tempfile
import zipfile
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import IO, Any

import luadata
from veaf_libs.logger import logger
from veaf_libs.safe_zip import safe_extract_all, safe_read_member

from .mission_constants import DEFAULT_SCRIPTS_LOCATION


@dataclass
class Group:
    """Canonical representation of a DCS aircraft/helicopter group."""

    group_dcs: dict
    aircraft_type: str  # "helicopter" | "plane"
    country: str
    coalition: str
    human_pilot: bool = False
    name: str | None = None
    unit_type: str | None = None


@dataclass
class DcsMission:
    """Class representing a DCS mission."""

    file_path: Path
    mission_content: dict | None = None
    options_content: dict | None = None
    theatre_content: str | None = ""
    warehouses_content: dict | None = None
    dictionary_content: dict[str, str] | None = None
    map_resource_content: dict[str, str] | None = None
    missing_components: list = field(default_factory=list)

    def iter_groups(self) -> Iterator[Group]:
        """Iterate over all aircraft/helicopter groups in the mission.

        Yields Group instances for every group found under
        coalition → country → {helicopter,plane} → group.
        """
        if not self.mission_content:
            return
        coalitions = self.mission_content.get("coalition")
        if not coalitions:
            return
        for coalition_name, coalition_data in coalitions.items():
            countries = coalition_data.get("country") or []
            for country_dict in countries:
                country_name = country_dict.get("name", "")
                for aircraft_type in ("helicopter", "plane"):
                    aircraft_data = country_dict.get(aircraft_type)
                    if not aircraft_data:
                        continue
                    groups_list = aircraft_data.get("group") or []
                    for group_dict in groups_list:
                        group = Group(
                            group_dcs=group_dict,
                            aircraft_type=aircraft_type,
                            country=country_name,
                            coalition=coalition_name,
                        )
                        group.name = group_dict.get("name")
                        units_list = group_dict.get("units") or []
                        for unit in units_list:
                            if unit_type := unit.get("type", ""):
                                group.unit_type = unit_type
                            if unit.get("skill", "") in ("Client", "Player"):
                                group.human_pilot = True
                                break
                        yield group

    # ------------------------------------------------------------------
    # Convenience accessors (DEEP-002)
    # ------------------------------------------------------------------

    def get_weather(self) -> dict | None:
        """Return the weather dict from mission_content, or None."""
        return self.mission_content.get("weather") if self.mission_content else None

    def set_weather(self, data: dict) -> None:
        """Replace the weather dict in mission_content."""
        if self.mission_content is not None:
            self.mission_content["weather"] = data

    def get_options(self) -> dict | None:
        """Return options_content."""
        return self.options_content

    def set_options(self, data: dict) -> None:
        """Replace options_content."""
        self.options_content = data


def read_miz(miz_file_path: Path) -> DcsMission:
    """Load the mission from the .miz file (unzip it and parse the lua files)."""

    def unserialize(
        file: IO[bytes], keep_as_dict: list[str] | None = None, all_is_dict: bool = False
    ) -> dict[str, Any]:
        with io.TextIOWrapper(file, encoding="utf-8") as wrapper:  # type: ignore[arg-type]
            return luadata.unserialize(wrapper.read(), keep_as_dict=keep_as_dict, all_is_dict=all_is_dict)  # type: ignore[return-value]

    def read_file_in_archive(
        zip_file: zipfile.ZipFile,
        file_name: str,
        missing_components: list[str],
        keep_as_dict: list[str] | None = None,
        not_lua: bool = False,
    ) -> dict[str, Any] | str | None:
        if file_name in zip_file.namelist():
            # VMR-009: capped read. A `.miz` is untrusted input, and this path pulls the
            # member straight into memory, so an unbounded `.read()` here is a zip bomb
            # that never has to touch the disk `safe_extract_all` protects.
            raw = safe_read_member(zip_file, file_name)
            if not_lua:
                return raw.decode("utf-8")
            return unserialize(io.BytesIO(raw), keep_as_dict=keep_as_dict)
        else:
            missing_components.append(file_name)
            return None

    result = DcsMission(file_path=miz_file_path)

    with zipfile.ZipFile(miz_file_path, "r") as miz:
        result.mission_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "mission", result.missing_components, keep_as_dict=["trig", "trigrules"]
        )
        result.options_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "options", result.missing_components
        )
        result.theatre_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "theatre", result.missing_components, not_lua=True
        )
        result.warehouses_content = read_file_in_archive(  # type: ignore[assignment]
            miz, "warehouses", result.missing_components
        )
        result.dictionary_content = read_file_in_archive(  # type: ignore[assignment]
            miz, f"{DEFAULT_SCRIPTS_LOCATION}/dictionary", result.missing_components
        )
        result.map_resource_content = read_file_in_archive(  # type: ignore[assignment]
            miz, f"{DEFAULT_SCRIPTS_LOCATION}/mapResource", result.missing_components
        )

    return result


def _find_mission_root(folder_path: Path) -> Path | None:
    """Locate the directory holding the loose ``mission`` file.

    Accepts both an extracted ``.miz`` tree (``mission`` at the folder root) and a VEAF source
    project (``src/mission/mission``).

    Args:
        folder_path: The folder to inspect.

    Returns:
        The directory containing the ``mission`` file, or ``None`` when none is found.
    """
    for candidate in (folder_path, folder_path / "src" / "mission"):
        if (candidate / "mission").is_file():
            return candidate
    return None


def read_mission_folder(folder_path: Path) -> DcsMission:
    """Load a mission from an extracted folder (no zip, no Lua execution).

    Reads the loose ``mission`` / ``options`` / ``warehouses`` / ``theatre`` /
    ``l10n/DEFAULT/{dictionary,mapResource}`` files that an unzipped ``.miz`` — or a VEAF source
    tree (``src/mission/``) — lays out on disk. It mirrors :func:`read_miz` but without a ZIP, using
    the same pure-Python ``luadata`` parser, so Lua is never executed.

    Args:
        folder_path: A directory holding the loose mission files, either at its root or under
            ``src/mission/``.

    Returns:
        The parsed :class:`DcsMission`.

    Raises:
        FileNotFoundError: when no ``mission`` file can be located under *folder_path*.
    """
    root = _find_mission_root(folder_path)
    if root is None:
        raise FileNotFoundError(f"No 'mission' file found under {folder_path} (looked in '.' and 'src/mission')")

    result = DcsMission(file_path=folder_path)

    def read_loose_file(rel_path: str, *, keep_as_dict: list[str] | None = None, not_lua: bool = False) -> Any:
        path = root / rel_path
        if not path.is_file():
            result.missing_components.append(rel_path)
            return None
        text = path.read_text(encoding="utf-8")
        return text if not_lua else luadata.unserialize(text, keep_as_dict=keep_as_dict)

    result.mission_content = read_loose_file("mission", keep_as_dict=["trig", "trigrules"])
    result.options_content = read_loose_file("options")
    result.theatre_content = read_loose_file("theatre", not_lua=True)
    result.warehouses_content = read_loose_file("warehouses")
    result.dictionary_content = read_loose_file(f"{DEFAULT_SCRIPTS_LOCATION}/dictionary")
    result.map_resource_content = read_loose_file(f"{DEFAULT_SCRIPTS_LOCATION}/mapResource")

    return result


def write_mission_folder(mission: DcsMission, folder_path: Path) -> Path:
    """Serialize ``mission_content`` back to a folder's loose ``mission`` file.

    The write-side counterpart of :func:`read_mission_folder`. Rewrites the ``mission`` table and,
    when the folder has one, the ``warehouses`` table — the two a caller can mutate through
    :class:`DcsMission`. Everything else in ``src/mission/`` is left untouched. Uses the same
    ``luadata`` serializer as :func:`write_miz`, so no Lua is executed.

    ``warehouses`` used to be skipped, which made `set_airbase_coalition` a fail-silent: it mutated
    the table, called this, and reported ``durable: True`` while the file on disk never changed —
    an airfield's coalition lives in ``warehouses``, not in ``mission`` (FIX-EMPTY-WAREHOUSES). The
    file is only rewritten when the folder already has one, so this never invents a member the
    mission did not carry.

    Args:
        mission: The mission whose tables to write.
        folder_path: A folder holding the loose mission files (root or ``src/mission/``).

    Returns:
        The path of the ``mission`` file written.

    Raises:
        FileNotFoundError: when no ``mission`` file can be located under *folder_path*.
        ValueError: when `mission.mission_content` is ``None``.
    """
    root = _find_mission_root(folder_path)
    if root is None:
        raise FileNotFoundError(f"No 'mission' file found under {folder_path} (looked in '.' and 'src/mission')")
    if mission.mission_content is None:
        raise ValueError("mission_content is None — nothing to write")
    lua_content = luadata.serialize(
        mission.mission_content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True
    )
    mission_file = root / "mission"
    mission_file.write_text(f"mission = \n{lua_content}", encoding="utf-8")

    warehouses_file = root / "warehouses"
    if mission.warehouses_content is not None and warehouses_file.is_file():
        warehouses_lua = luadata.serialize(
            mission.warehouses_content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True
        )
        warehouses_file.write_text(f"warehouses = \n{warehouses_lua}", encoding="utf-8")

    return mission_file


def create_miz(miz_file_path: Path, files: dict[str, bytes]) -> Path:
    """Create an mission in a .miz file with new data (zip it)."""

    # Normalize files to avoid None errors
    files = files or {}

    if miz_file_path:
        with zipfile.ZipFile(miz_file_path, "w") as zip_write:
            for file_name, file_content in files.items():
                zip_write.writestr(zinfo_or_arcname=str(file_name), data=file_content)

    return miz_file_path


def write_miz(mission: DcsMission, miz_file_path: Path | None, additional_files: dict | None = None) -> DcsMission:
    """Update an existing mission in a .miz file with new data (zip it)."""

    def serialize(zip_file: zipfile.ZipFile, content: Any, file_name: str, variable_name: str | None = None) -> None:
        lua_content = luadata.serialize(content, indent="  ", indent_level=0, always_provide_keyname=True, sort=True)  # type: ignore[arg-type]
        zip_file.writestr(file_name, f"{variable_name} = \n{lua_content}" if variable_name else lua_content)

    if not miz_file_path:
        miz_file_path = mission.file_path

    # Normalize additional_files to avoid None errors
    additional_files = additional_files or {}

    # VMR-053: the temp file is created and its handle closed straight away. It used to be held
    # open by a `NamedTemporaryFile` context while `zipfile.ZipFile` wrote to that same path, and on
    # Windows that made the cleanup impossible: `os.unlink` on a file we still have open fails with a
    # sharing violation, the surrounding `suppress(OSError)` swallowed it, and every failed build
    # left a `veaf_mission_*.miz` in the mission folder. The write stays atomic — same directory as
    # the target, then `os.replace`.
    temp_fd, temp_name = tempfile.mkstemp(
        suffix=".miz",  # Proper extension
        prefix="veaf_mission_",  # Identifiable prefix
        dir=miz_file_path.parent,  # Same directory as target (for atomic moves)
    )
    os.close(temp_fd)
    temp_zip_path = temp_name
    # Separate from the path above, because it answers a different question: is there still
    # something on disk that we own and must remove?
    path_to_clean_up: str | None = temp_name

    try:
        try:
            # Read all files from the original mission file
            with zipfile.ZipFile(mission.file_path, "r") as zip_read:
                file_list = zip_read.namelist()

                # Copy all files except the ones we're updating
                with zipfile.ZipFile(temp_zip_path, "w", zipfile.ZIP_DEFLATED) as zip_write:
                    for file_name in file_list:
                        if file_name == "mission":
                            if mission.mission_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.mission_content,
                                    file_name="mission",
                                    variable_name="mission",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "options":
                            if mission.options_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.options_content,
                                    file_name="options",
                                    variable_name="options",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "theatre":
                            if mission.theatre_content:
                                zip_write.writestr("theatre", mission.theatre_content)
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == "warehouses":
                            if mission.warehouses_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.warehouses_content,
                                    file_name="warehouses",
                                    variable_name="warehouses",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == f"{DEFAULT_SCRIPTS_LOCATION}/dictionary":
                            if mission.dictionary_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.dictionary_content,
                                    file_name=f"{DEFAULT_SCRIPTS_LOCATION}/dictionary",
                                    variable_name="dictionary",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name == f"{DEFAULT_SCRIPTS_LOCATION}/mapResource":
                            if mission.map_resource_content:
                                serialize(
                                    zip_file=zip_write,
                                    content=mission.map_resource_content,
                                    file_name=f"{DEFAULT_SCRIPTS_LOCATION}/mapResource",
                                    variable_name="mapResource",
                                )
                            else:
                                zip_write.writestr(file_name, zip_read.read(file_name))
                        elif file_name in additional_files:
                            # Skip it - will be added from additional_files
                            pass
                        else:
                            # Copy existing file as-is
                            zip_write.writestr(file_name, zip_read.read(file_name))

                    # Add the additional files
                    for additional_file_name, additional_file_content in additional_files.items():
                        zip_write.writestr(additional_file_name, additional_file_content)

        except Exception as e:
            # `logger.exception` re-raises the same exception type, so the caller learns the write
            # failed rather than getting a mission object back as if it had worked. That was already
            # the behaviour; what the old code added below it — clearing `temp_zip_path` to "prevent
            # replacing the original with a broken temp file" — was unreachable, and the cleanup now
            # lives in the `finally` so it also covers a failing `os.replace`.
            logger.exception(e)

        # Move the temp file to its final location. Once it is renamed there is nothing of ours
        # left on disk.
        os.replace(temp_zip_path, miz_file_path)
        path_to_clean_up = None
    finally:
        if path_to_clean_up:
            with contextlib.suppress(OSError):
                os.unlink(path_to_clean_up)

    return mission


def extract_miz(miz_file_path: Path, extracted_folder_path: Path):
    """Extract the mission from the .miz file (unzip it)."""

    # Extract all files to a folder (validated against Zip Slip / zip bombs)
    with zipfile.ZipFile(miz_file_path, "r") as zip_ref:
        safe_extract_all(zip_ref, extracted_folder_path)


def list_members(miz_file_path: Path) -> list[str]:
    """Return the archive-member names of a ``.miz`` (without extracting)."""
    with zipfile.ZipFile(miz_file_path, "r") as zip_read:
        return zip_read.namelist()


def read_member(miz_file_path: Path, arcname: str) -> bytes:
    """Return the raw bytes of one ``.miz`` archive member."""
    with zipfile.ZipFile(miz_file_path, "r") as zip_read:
        return zip_read.read(arcname)


def rewrite_miz_members(miz_file_path: Path, replacements: dict[str, bytes]) -> None:
    """Rewrite specific ``.miz`` members verbatim, copying every other member unchanged.

    Unlike :func:`write_miz`, this does NOT re-serialize the ``mission`` / ``options`` /
    ``dictionary`` Lua tables — it copies the whole archive through byte-for-byte and only
    swaps the members named in *replacements*. Use it to edit an embedded text file (e.g.
    ``l10n/DEFAULT/veaf-config.lua``) without normalising the rest of the mission. The write
    is atomic (temp file + ``os.replace``).

    Args:
        miz_file_path: The ``.miz`` to rewrite in place.
        replacements: ``arcname -> new bytes`` for the members to overwrite. Members that
            don't already exist in the archive are added.
    """
    temp_zip_path: str | None = None
    with tempfile.NamedTemporaryFile(
        suffix=".miz", prefix="veaf_mission_", delete=False, dir=miz_file_path.parent
    ) as temp_file:
        temp_zip_path = temp_file.name
        try:
            with zipfile.ZipFile(miz_file_path, "r") as zip_read:
                existing = zip_read.namelist()
                with zipfile.ZipFile(temp_zip_path, "w", zipfile.ZIP_DEFLATED) as zip_write:
                    for name in existing:
                        if name in replacements:
                            zip_write.writestr(name, replacements[name])
                        else:
                            zip_write.writestr(name, zip_read.read(name))
                    for name, content in replacements.items():
                        if name not in existing:
                            zip_write.writestr(name, content)
        except Exception as e:
            with contextlib.suppress(OSError):
                os.unlink(temp_zip_path)
            logger.exception(e)
            temp_zip_path = None
    if temp_zip_path:
        os.replace(temp_zip_path, miz_file_path)


#: Archive members already carried by the JSON export object; skipped by :func:`extract_resources`.
_EXPORT_DATA_MEMBERS: frozenset[str] = frozenset(
    {
        "mission",
        "options",
        "warehouses",
        "theatre",
        f"{DEFAULT_SCRIPTS_LOCATION}/dictionary",
        f"{DEFAULT_SCRIPTS_LOCATION}/mapResource",
    }
)


def extract_resources(miz_file_path: Path, dest_path: Path) -> list[str]:
    """Extract a ``.miz``'s embedded resources (scripts, l10n sounds/images) to *dest_path*.

    The mission *data* files (``mission`` / ``dictionary`` / ``mapResource`` / …) are already
    carried by the JSON export object, so they are skipped: only the files the plugin cannot get
    from the JSON — Lua scripts and ``l10n/DEFAULT/*`` assets — are written, preserving the archive
    layout. Extraction goes through :func:`safe_extract_all` (Zip Slip / zip-bomb hardened).

    Args:
        miz_file_path: The source ``.miz`` archive.
        dest_path: Destination directory for the extracted resources.

    Returns:
        The list of extracted member names (archive-relative paths).
    """
    with zipfile.ZipFile(miz_file_path, "r") as zip_ref:
        resources = [
            info.filename
            for info in zip_ref.infolist()
            if not info.is_dir() and info.filename not in _EXPORT_DATA_MEMBERS
        ]
        if resources:
            safe_extract_all(zip_ref, dest_path, members=set(resources))
    return resources
