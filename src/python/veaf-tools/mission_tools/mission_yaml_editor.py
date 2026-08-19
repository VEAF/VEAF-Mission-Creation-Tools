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
from ruamel.yaml.comments import CommentedMap, CommentedSeq

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
    # newline="\n" or Python rewrites every line ending as CRLF on Windows, so a call meant to
    # touch one section changes the whole file (measured 2026-08-19: LF 11 -> CRLF 11). Every
    # `mission.yaml` in this repository is LF.
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        _yaml().dump(data, handle)
    return backup_path


#: Where ruamel stores a comment on a node: [pre, _, post, _] on a mapping key, [post, ...] on a
#: sequence index. Named so the index juggling below reads as intent rather than as magic numbers.
_MAP_POST = 2
_SEQ_POST = 0


def append_to_sequence(sequence: list, entry: object) -> None:
    """Append `entry` after a sequence's last **item**, not after the comment block trailing it.

    ruamel attaches a comment to the node it follows, so a commented-out block sitting under the
    last list item belongs to *that item*. A plain ``list.append`` then writes the new entry below
    the comment: the value parses fine (comments do not interrupt a sequence), and the file reads as
    if the entry belonged to whatever section the comment introduces. Measured on 2026-08-18 while
    building ``verify-mission-c``, where two combat zones landed 54 lines below their own list, under
    the community-scripts heading — and ``mission.yaml`` is a file mission makers edit by hand, so an
    entry under the wrong heading is one they move or delete.

    The trailing comment is therefore detached from the old last item and re-attached to the new one.

    Args:
        sequence: The round-trip sequence to append to.
        entry: The value to append. A plain ``dict`` is wrapped so the comment can be re-attached to
            its last key, which is where ruamel renders a *following* comment for a mapping item.
    """
    if not isinstance(sequence, CommentedSeq):
        # A list this call just created carries no comments, so there is nothing to step over.
        sequence.append(entry)
        return

    owner, key, slot = _trailing_comment(sequence)
    token = None
    if owner is not None:
        token = owner.ca.items[key][slot]
        owner.ca.items[key][slot] = None

    sequence.append(CommentedMap(entry) if isinstance(entry, dict) and not isinstance(entry, CommentedMap) else entry)

    if token is not None:
        last_index = len(sequence) - 1
        last = sequence[last_index]
        if isinstance(last, CommentedMap) and last:
            last.ca.items.setdefault(list(last.keys())[-1], [None, None, None, None])[_MAP_POST] = token
        else:
            sequence.ca.items.setdefault(last_index, [None, None, None, None])[_SEQ_POST] = token


def _trailing_comment(sequence: CommentedSeq) -> tuple[CommentedMap | CommentedSeq | None, object, int]:
    """Locate the comment following a sequence's last item.

    Args:
        sequence: The sequence to inspect.

    Returns:
        ``(owner, key, slot)`` identifying the comment's storage, or ``(None, None, 0)`` when the
        last item has nothing after it.
    """
    if not sequence:
        return None, None, 0
    last_index = len(sequence) - 1
    last = sequence[last_index]
    if isinstance(last, CommentedMap) and last:
        last_key = list(last.keys())[-1]
        if last.ca.items.get(last_key, [None, None, None, None])[_MAP_POST] is not None:
            return last, last_key, _MAP_POST
    if sequence.ca.items.get(last_index, [None, None, None, None])[_SEQ_POST] is not None:
        return sequence, last_index, _SEQ_POST
    return None, None, 0
