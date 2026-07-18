"""Comment-preserving load/save of the source ``mission.yaml`` (wave-4 VMCT brick).

The rest of the codebase reads ``mission.yaml`` with PyYAML ``yaml.safe_load``, which
discards every comment and all formatting on a round-trip. ``mission.yaml`` is a heavily
commented **source** file that Mission Makers edit by hand (and the shipped default is kept
in lockstep with generated output), so the VMCT MCP actions must not flatten it. This brick
wraps ``ruamel.yaml`` in round-trip mode so comments, key order, quoting and layout survive,
and backs the file up before every write — the same safety contract as the editor-parity
actions (see ``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md``).
"""

from pathlib import Path

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap

from mission_tools.miz_backup import backup_before_write


def _yaml() -> YAML:
    """Build a round-trip YAML handler configured to match ``mission.yaml``'s layout.

    Returns:
        A ``ruamel.yaml.YAML`` instance in round-trip mode (2-space mapping and block
        sequence indentation, preserved quotes, no line-width reflow).
    """
    yaml = YAML()  # round-trip ('rt') is the default type
    yaml.preserve_quotes = True
    yaml.width = 4096  # never re-wrap long lines
    yaml.indent(mapping=2, sequence=4, offset=2)
    return yaml


def load_yaml(path: Path) -> CommentedMap:
    """Load ``mission.yaml`` preserving comments, key order and formatting.

    Args:
        path: Path to the ``mission.yaml`` to read.

    Returns:
        The parsed document as a ``ruamel.yaml`` ``CommentedMap`` (round-trip aware).

    Raises:
        FileNotFoundError: If `path` does not exist.
    """
    with path.open("r", encoding="utf-8") as handle:
        data: CommentedMap = _yaml().load(handle)
    return data


def save_yaml(path: Path, data: CommentedMap) -> Path:
    """Back up `path`, then write `data` back preserving comments and formatting.

    Args:
        path: Path to the ``mission.yaml`` to overwrite in place.
        data: The (possibly mutated) round-trip document to serialize.

    Returns:
        The path of the timestamped backup taken before the write.
    """
    backup_path = backup_before_write(path)
    with path.open("w", encoding="utf-8") as handle:
        _yaml().dump(data, handle)
    return backup_path
