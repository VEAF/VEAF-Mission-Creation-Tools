import re
from pathlib import Path

from veaf_libs.i18n import t

DEFAULT_SCRIPTS_LOCATION: str = "l10n/DEFAULT"


def get_legacy_script_files() -> list[tuple[str, str]]:
    """Get list of files that should be removed from any newly extracted mission; they are old VEAF files that are not used anymore"""

    return [
        # The VEAF scripts
        ("src/scripts/veaf/veaf-scripts-debug.lua", DEFAULT_SCRIPTS_LOCATION),
        ("src/scripts/veaf/veaf-scripts-trace.lua", DEFAULT_SCRIPTS_LOCATION),
    ]


def get_community_script_files() -> list[dict[str, str]]:
    """Get list of community LUA files.

    Each entry is a dict with keys:
        - ``id``: stable identifier used in ``community_scripts:`` section of ``mission.yaml``
        - ``path``: source path relative to the scripts root
        - ``dest``: destination location inside the ``.miz`` archive

    Returns:
        List of community script descriptors.
    """

    return [
        {"id": "mist", "path": "src/scripts/community/mist.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "stts", "path": "src/scripts/community/DCS-SimpleTextToSpeech.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "ctld", "path": "src/scripts/community/CTLD.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "aien", "path": "src/scripts/community/AIEN.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "csar", "path": "src/scripts/community/CSAR.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "skynet", "path": "src/scripts/community/skynet-iads-compiled.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
        {"id": "tum", "path": "src/scripts/community/TheUniversalMission.lua", "dest": DEFAULT_SCRIPTS_LOCATION},
    ]


def get_optin_community_script_ids() -> set[str]:
    """Community script ids that are OFF unless explicitly enabled (opt-in).

    Most community scripts are opt-out (active by default unless turned off). A few
    impose a mission-design contract and must never start on their own — e.g. TUM
    (TheUniversalMission) requires BLUFOR/REDFOR territory zones each owning an
    airbase, and raises a start-up error otherwise. Those are opt-in: a vanilla
    mission, a freshly converted v5 mission, or a ``modules:`` block that does not
    mention them leaves them disabled; only ``<ID>: true`` turns them on.

    MiST joined this set for a different reason (DROP-MIST ticket 08). It used to be
    injected into every mission because the VEAF scripts called it; they no longer do,
    and neither does any community script we ship. Carrying 336 KB into every ``.miz``
    for nobody is what made it opt-in — but a mission maker's own script may still call
    it, so the builder turns it back on by itself when it finds ``mist.`` in one of them.
    See ``mission_scripts_referencing_mist``.
    """
    return {"tum", "mist"}


def is_community_script_enabled_by_default(script_id: str) -> bool:
    """Return whether a community script is active when not explicitly listed.

    This is the single source of truth for the "no ``community_scripts:`` section,
    or id not listed" case, shared by the builder enablement and the config
    generator so the two paths cannot drift apart: opt-out scripts default to
    enabled, opt-in scripts (see :func:`get_optin_community_script_ids`) default
    to disabled.

    Args:
        script_id: The community script id (e.g. ``"ctld"``, ``"tum"``).

    Returns:
        True when the script is on by default, False for opt-in scripts.
    """
    return script_id not in get_optin_community_script_ids()


def get_community_sound_files() -> dict[str, tuple[str, ...]]:
    """Sound assets required by community scripts, keyed by community script id.

    CTLD and CSAR play these ``.ogg`` files by name at runtime
    (``outSoundForCoalition("beacon.ogg")`` …), so the files must be packaged in
    the mission's ``l10n/DEFAULT/`` folder. The tool ships them under
    ``src/scripts/community/sounds/`` and the build injects the ones a mission
    is missing when the owning module is enabled.

    Returns:
        Mapping of community script id to the sound filenames it requires.
    """

    return {
        "ctld": ("beacon.ogg", "beaconsilent.ogg", "radiobeep.ogg"),
        "csar": ("beacon.ogg", "CSAR.ogg"),
    }


def get_veaf_script_files() -> list[tuple[str, str]]:
    """Get list of VEAF script files.Those can be in published or in the scripts folder, depending on the --dynamic-mode option"""

    return [
        # The main VEAF scripts
        ("src/scripts/veaf/veaf-scripts.lua", DEFAULT_SCRIPTS_LOCATION)
    ]


def get_mission_script_files() -> list[tuple[str, str]]:
    """Get list of the mission files. Those are either in the mission folder or in the VEAF defaults folder"""

    return [
        # Optional generated module config; loaded BEFORE mission-script.lua
        ("src/scripts/veaf-config.lua", DEFAULT_SCRIPTS_LOCATION),
        # The mission scripts
        ("src/scripts/mission-script.lua", DEFAULT_SCRIPTS_LOCATION),
        # veafDynamicConfig.lua is packaged but never read from the archive, and that is
        # understood rather than accidental (FIX-COMMUNITY-SOUNDS-PRUNED ticket 02): dynamic mode
        # loads it off disk through VEAF_DYNAMIC_MISSIONPATH, and static mode does not load it at
        # all — `_ordered_mission_script_files` excludes it on purpose, since it *is* the dynamic
        # loader. Left in because the `src/scripts/*.lua` catch-all below would package it anyway,
        # and narrowing that glob to save 780 bytes risks silently dropping a mission maker's own
        # script. The Mission Editor prunes the copy on save; nothing depends on it.
        ("src/scripts/veafDynamicConfig.lua", DEFAULT_SCRIPTS_LOCATION),
        ("src/scripts/*.lua", DEFAULT_SCRIPTS_LOCATION),
    ]


def get_mission_data_files() -> list[tuple[str, str]]:
    """Get list of the mission files. Those are either in the mission folder or in the VEAF defaults folder"""

    return [
        # The mission files
        ("src/mission/**", ""),
        # The options file
        ("src/options", ""),
    ]


def get_mission_files_to_cleanup_on_extract() -> list[tuple[str, bool]]:
    """Get list of the mission files that need to be cleaned up when extracting a mission file."""

    return [
        (f"{DEFAULT_SCRIPTS_LOCATION}/mission-script.lua", True),
        (f"{DEFAULT_SCRIPTS_LOCATION}/veafDynamicConfig.lua", True),
        ("options", False),
        ("mission/Config", False),
        ("mission/Scripts", False),
        ("mission/track", False),
        ("mission/track_data", False),
    ]


def collect_files_from_globs(
    base_folder: Path, file_patterns: list[tuple[str, str]], alternative_folder: Path | None = None, logger=None
) -> dict[str, bytes]:
    """
    Collect files from a base folder using file paths and glob patterns.
    Falls back to alternative_folder if files cannot be found in base_folder.

    Args:
        base_folder: The base directory to search from
        file_patterns: List of file paths or glob patterns (e.g., "src/scripts/*.lua", "src/mission/*")
        alternative_folder: Optional fallback folder to search if no files are found in base_folder

    Returns:
        Dictionary with:
            - key: relative file path from base_folder (with subfolders)
            - value: file contents as bytes
    """

    def _add_file_to_results(results: dict[str, bytes], file_path: Path, base_folder: Path) -> None:
        relative_path = file_path.relative_to(base_folder).parent.as_posix()
        key = (dest_location / relative_path / file_path.name).as_posix()
        if logger:
            logger.debug(f"Processing file {key}")
        results[key] = file_path.read_bytes()

    def _search_pattern_in_folder(search_folder: Path, pattern: str) -> dict[str, bytes]:
        """Search for files matching pattern in the given folder."""
        if not search_folder.exists():
            return {}

        pattern_path = search_folder / pattern
        folder = pattern_path.parent
        glob_pattern = pattern_path.name

        if not folder.exists():
            return {}

        matched_files: dict[str, bytes] = {}

        if "**" in pattern:
            parts = Path(pattern).parts
            if "**" in parts:
                glob_start_index = parts.index("**")
                pattern_search_folder = (
                    search_folder / Path(*parts[:glob_start_index]) if glob_start_index > 0 else search_folder
                )
                remaining_pattern = str(Path(*parts[glob_start_index:]))
                if pattern_search_folder.exists():
                    for f in pattern_search_folder.rglob(remaining_pattern):
                        if f.is_file():
                            _add_file_to_results(matched_files, f, folder)
        else:
            matched_files = {}
            for f in folder.glob(glob_pattern):
                if f.is_file():
                    _add_file_to_results(matched_files, f, folder)

        return matched_files

    files_dict: dict[str, bytes] = {}

    for file_info in file_patterns:
        pattern = file_info[0]
        dest_location = Path(file_info[1])

        # Try to find files in base_folder first
        matched_files = _search_pattern_in_folder(base_folder, pattern)

        # If no files found and alternative_folder is provided, try there
        if not matched_files and alternative_folder is not None:
            if logger:
                logger.debug(
                    f"No files found in {base_folder} for pattern {pattern}, trying alternative folder {alternative_folder}"
                )
            matched_files = _search_pattern_in_folder(alternative_folder, pattern)
            if matched_files and logger:
                logger.warning(
                    t("mission_tools.alternative_folder", alt=alternative_folder, file=pattern, orig=base_folder)
                )

        # Add matched files to result
        files_dict = files_dict | matched_files

    return files_dict


#: Matches a call to MiST: ``mist``, a dot, and an identifier.
#:
#: The lookbehind rejects ``chemist.brew()`` and ``a.mist.z``. The ``\s*`` are not pedantry — Lua
#: allows whitespace around a dot, so ``mist . utils.round(x)`` is a call and missing it would leave
#: a mission without MiST until it died in DCS. Same for the leading underscore: ``mist._helper()``
#: is a legal member name.
_MIST_CALL_RE = re.compile(r"(?<![\w.])mist\s*\.\s*[A-Za-z_]\w*")

#: Everything that looks like code but is not: comments and string literals.
#:
#: Removed before looking for a call, because a mention in either is not one. ``CTLD.lua`` carries an
#: error *message* naming ``mist.DBs.MEgroupsByName``, and counting that as a call is how an earlier
#: pass reported CTLD as still needing MiST when it has not since v2.
#:
#: Order matters. ``--[[`` must be tried before ``--``, or a block comment would be trimmed to its
#: first line and the rest read as code. Long brackets carry any number of equals signs
#: (``[==[ … ]==]``), and a quoted string may contain escaped quotes — both were missed by the first
#: version of this, which worked line by line and could not see a comment spanning several.
#:
#: This is not a Lua lexer, and does not try to be: an unterminated long bracket degrades to the
#: line-comment branch. What it costs when it is wrong is 336 KB in a mission that did not need
#: them — the opposite mistake, missing a real call, is the one that breaks a mission in flight.
_LUA_NOISE_RE = re.compile(
    r"--\[(?P<bc>=*)\[.*?\](?P=bc)\]"  # block comment: --[[ … ]] and --[==[ … ]==]
    r"|--[^\n]*"  # line comment, including one trailing real code
    r"|\[(?P<ls>=*)\[.*?\](?P=ls)\]"  # long string: [[ … ]] and [==[ … ]==]
    r"|\"(?:\\.|[^\"\\\n])*\""  # "…", escaped quotes included
    r"|'(?:\\.|[^'\\\n])*'",  # '…', likewise
    re.DOTALL,
)


def mission_scripts_referencing_mist(scripts_dir: Path) -> list[str]:
    """Return the names of the mission's own scripts that call MiST.

    VEAF stopped injecting MiST into every mission (DROP-MIST ticket 08), which would silently break
    a mission whose own scripts call it: nothing fails at build time, and DCS reports
    ``attempt to index nil (global 'mist')`` from inside a third-party file at runtime. So the
    builder looks, and injects MiST when it finds a caller.

    Everything in ``src/scripts/*.lua`` is packaged, whether or not it is declared under
    ``custom_scripts:``, so the whole folder is scanned rather than the declared list.

    A comment is not a call, and neither is a mention inside a string. What this cannot see is an
    indirect use — a script that loads another script, or reaches MiST through ``_G``. For those,
    ``MIST: true`` in the ``modules:`` block is the explicit way to ask.

    Args:
        scripts_dir: The mission's ``src/scripts`` folder. A missing folder yields an empty list.

    Returns:
        The file names that call MiST, sorted, so a caller can name them in a log line.
    """
    if not scripts_dir.is_dir():
        return []

    callers: list[str] = []
    for lua_file in sorted(scripts_dir.glob("*.lua")):
        try:
            text = lua_file.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        # The whole file at once, not line by line: a block comment or a long string spans several
        # lines, and the first version of this could not see past the end of one.
        # A space rather than nothing, so removing a string cannot weld its neighbours into a token.
        if _MIST_CALL_RE.search(_LUA_NOISE_RE.sub(" ", text)):
            callers.append(lua_file.name)
    return callers
