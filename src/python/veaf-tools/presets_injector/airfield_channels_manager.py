"""Choose which airfields of a mission get a radio channel, with DCS's own frequencies.

A DCS radio holds about twenty presets; a theatre has 21 to 119 airfields. A mission can only carry
the ones it uses, and nothing used to help choose them — which is how two v6 missions shipped a
series of base frequencies nobody had checked against DCS (FEAT-AIRFIELD-CHANNELS-FROM-DCS).

This module reads what the mission already says about its airfields — who holds each one in
``warehouses``, whether it offers dynamic slots once ``src/warehouses.yaml`` is applied, how many
player slots are parked on it — ranks them, and writes the chosen ones into the ``bases`` channel
collection of ``src/presets.yaml``. Frequencies only ever come from the reference
(``veaf_libs/data/airfield-frequencies.yaml``, captured from DCS): an airfield the reference does
not know is refused, never invented.

The same functions serve the ``veaf-tools`` command and the MCP actions, so a human at the CLI and
Claude while authoring get the same list and the same write.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from mission_tools.miz_tools import DcsMission
from veaf_libs.bundled_data import read_bundled_text

#: The channel collection this module owns in a mission's ``src/presets.yaml``.
BASES_COLLECTION = "bases"

_BANDS = ("uhf", "vhf", "fm")
_COALITIONS = {"BLUE": "blue", "RED": "red", "NEUTRAL": "neutral"}


@dataclass(frozen=True)
class AirfieldCandidate:
    """One airfield of the mission's theatre, as the mission uses it."""

    airdrome_id: int
    name: str
    coalition: str
    """``blue``, ``red`` or ``neutral``, from ``warehouses.airports[<id>].coalition``."""
    dynamic_slots: bool
    """Whether the build leaves it offering dynamic slots (``src/warehouses.yaml`` applied)."""
    parked_slots: int
    """Player units whose group starts on this airfield."""
    freqs: dict[str, float] = field(default_factory=dict)
    tacan: str | None = None
    channel: str | None = None
    """The alias this airfield already has in the mission's ``bases`` collection, if any."""

    @property
    def tier(self) -> int:
        """0: held with slots, 1: held without, 2: neutral — the order a proposal follows."""
        if self.coalition == "neutral":
            return 2
        return 0 if self.dynamic_slots or self.parked_slots else 1

    def as_dict(self) -> dict[str, Any]:
        """Return the JSON-friendly form the CLI and the MCP actions print.

        Returns:
            Every field, plus ``tier``.
        """
        return {
            "airdrome_id": self.airdrome_id,
            "name": self.name,
            "coalition": self.coalition,
            "dynamic_slots": self.dynamic_slots,
            "parked_slots": self.parked_slots,
            "freqs": dict(self.freqs),
            "tacan": self.tacan,
            "channel": self.channel,
            "tier": self.tier,
        }


def load_reference(theatre: str) -> dict[int, dict[str, Any]]:
    """Return the shipped reference of one theatre.

    Args:
        theatre: Runtime theatre name (``env.mission.theatre``).

    Returns:
        Airdrome id -> ``{name, uhf?, vhf?, fm?, tacan?}``; empty for an unknown theatre.
    """
    data = yaml.safe_load(read_bundled_text("veaf_libs", "data", "airfield-frequencies.yaml")) or {}
    return {int(k): v for k, v in ((data.get("theatres") or {}).get(theatre) or {}).items()}


def _parked_slots(mission: DcsMission) -> dict[int, int]:
    """Count the player units parked on each airfield (dynamic-slot templates excluded).

    Args:
        mission: The loaded mission.

    Returns:
        Airdrome id -> number of ``Client``/``Player`` units whose group's first point is on it.
    """
    counts: dict[int, int] = {}
    for group in mission.iter_groups():
        dcs = group.group_dcs
        if dcs.get("dynSpawnTemplate") is True:
            continue
        humans = [u for u in dcs.get("units") or [] if u.get("skill") in ("Client", "Player")]
        points = (dcs.get("route") or {}).get("points") or []
        airdrome_id = points[0].get("airdromeId") if points else None
        if humans and isinstance(airdrome_id, int):
            counts[airdrome_id] = counts.get(airdrome_id, 0) + len(humans)
    return counts


def _resolve_key(key: object, reference: dict[int, dict[str, Any]]) -> int | None:
    """Resolve an airfield written as an id or a name (case-insensitive) against the reference.

    Args:
        key: An id, a numeric string, or a name.
        reference: Output of :func:`load_reference`.

    Returns:
        The airdrome id, or ``None`` when nothing matches.
    """
    if isinstance(key, int) or (isinstance(key, str) and key.strip().isdigit()):
        return int(key) if int(key) in reference else None
    wanted = str(key).strip().casefold()
    return next((i for i, e in reference.items() if str(e["name"]).casefold() == wanted), None)


def _dynamic_after_build(
    airports: dict[Any, Any], warehouses_config: dict[str, Any], reference: dict[int, dict[str, Any]]
) -> dict[int, bool]:
    """Say, per airfield, whether it offers dynamic slots once the build applied ``warehouses.yaml``.

    Mirrors ``warehouses_injector.apply_warehouses``: a declared side opens the bases it lists under
    ``airports:`` (or all of its bases), minus ``exclude_airports``; an undeclared side keeps the
    mission's own ``dynamicSpawn``.

    Args:
        airports: ``warehouses.airports`` of the mission, keyed by id.
        warehouses_config: Parsed ``src/warehouses.yaml`` (``{}`` when absent).
        reference: The theatre's reference, to resolve names.

    Returns:
        Airdrome id -> dynamic slots offered.
    """
    result = {int(i): bool(a.get("dynamicSpawn")) for i, a in airports.items() if isinstance(a, dict)}
    for side in ("blue", "red"):
        cfg = warehouses_config.get(side)
        if not isinstance(cfg, dict):
            continue
        token = side.upper()
        listed = cfg.get("airports")
        if listed:
            targets = {_resolve_key(k, reference) for k in listed} - {None}
        else:
            targets = {int(i) for i, a in airports.items() if str(a.get("coalition", "")).upper() == token}
        for airdrome_id in targets:
            if airdrome_id is not None:
                result[airdrome_id] = True
        for key in cfg.get("exclude_airports") or []:
            airdrome_id = _resolve_key(key, reference)
            if airdrome_id is not None:
                result[airdrome_id] = False
    return result


def _normalise(text: str) -> str:
    """Reduce a channel alias or title to letters and digits, ``Base-`` prefix and TACAN dropped.

    Args:
        text: An alias (``Base-Sochi``) or a title (``Sochi / 18X``).

    Returns:
        The comparable form (``sochi``).
    """
    text = text.split("/")[0]
    text = re.sub(r"^\s*base[-_ ]", "", text, flags=re.IGNORECASE)
    return re.sub(r"[^0-9a-z]", "", text.casefold())


def _first_word(name: str) -> str:
    """Return the normalised first word of an airfield name.

    Args:
        name: An airfield name (``Sochi-Adler``).

    Returns:
        Its first word, normalised (``sochi``).
    """
    return _normalise(re.split(r"[- ]", name)[0])


def match_existing(bases: dict[str, Any], name: str, theatre_names: list[str]) -> str | None:
    """Find the alias an airfield already has in a ``bases`` collection.

    Matches the DCS name against each alias and title, and so does its first word when no other
    airfield of the theatre shares it — ``Base-Sochi`` is ``Sochi-Adler``, but ``Base-Krasnodar``
    is neither ``Krasnodar-Center`` nor ``Krasnodar-Pashkovsky``. Anything looser would guess.

    Args:
        bases: The mission's ``bases`` collection.
        name: The airfield's DCS name.
        theatre_names: Every airfield name of the theatre.

    Returns:
        The existing alias, or ``None``.
    """
    wanted = {_normalise(name)}
    first = _first_word(name)
    if sum(1 for other in theatre_names if _first_word(other) == first) == 1:
        wanted.add(first)
    for alias, channel in bases.items():
        title = channel.get("title", "") if isinstance(channel, dict) else ""
        if {_normalise(str(alias)), _normalise(str(title))} & wanted:
            return str(alias)
    return None


def list_candidates(
    mission: DcsMission,
    warehouses_config: dict[str, Any],
    bases: dict[str, Any],
    reference: dict[int, dict[str, Any]],
    include_neutral: bool = False,
) -> list[AirfieldCandidate]:
    """Rank the airfields of a mission for a radio channel.

    Args:
        mission: The loaded mission.
        warehouses_config: Parsed ``src/warehouses.yaml``.
        bases: The mission's current ``bases`` collection (``{}`` when absent).
        reference: The theatre's reference.
        include_neutral: Also list the airfields no side holds.

    Returns:
        Candidates, held-with-slots first, then held-without, then neutral; most parked slots first
        within a tier, then by name.
    """
    airports = (mission.warehouses_content or {}).get("airports") or {}
    dynamic = _dynamic_after_build(airports, warehouses_config, reference)
    parked = _parked_slots(mission)
    names = [str(e["name"]) for e in reference.values()]
    candidates = []
    for airdrome_id, entry in reference.items():
        raw = airports.get(airdrome_id) or {}
        coalition = _COALITIONS.get(str(raw.get("coalition", "NEUTRAL")).upper(), "neutral")
        if coalition == "neutral" and not include_neutral:
            continue
        candidates.append(
            AirfieldCandidate(
                airdrome_id=airdrome_id,
                name=str(entry["name"]),
                coalition=coalition,
                dynamic_slots=dynamic.get(airdrome_id, False),
                parked_slots=parked.get(airdrome_id, 0),
                freqs={b: entry[b] for b in _BANDS if b in entry},
                tacan=entry.get("tacan"),
                channel=match_existing(bases, str(entry["name"]), names),
            )
        )
    return sorted(candidates, key=lambda c: (c.tier, -c.parked_slots, c.name))


def channel_title(name: str, tacan: str | None) -> str:
    """Title an airfield channel the way every VEAF plan does: ``Batumi / 16X``, or the name alone.

    The one place the rule lives — the generated ``airports-<theatre>`` collections and a mission's
    ``bases`` must title the same field the same way.

    Args:
        name: The airfield's DCS name.
        tacan: Its TACAN channel (``16X``), or ``None``.

    Returns:
        The channel title.
    """
    return f"{name} / {tacan}" if tacan else name


def yaml_scalar(text: str) -> str:
    """Write a YAML scalar, quoted only when it needs it.

    Args:
        text: The plain string.

    Returns:
        The string as it should appear in YAML (``Batumi``, ``'01'``, ``"a: b"``…).
    """
    return (
        yaml.safe_dump(text, allow_unicode=True, default_flow_style=True, width=10_000)
        .strip()
        .removesuffix("\n...")
        .strip()
    )


def plan_bases(
    bases: dict[str, Any], chosen: list[str | int], reference: dict[int, dict[str, Any]], theatre: str
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    """Compute the ``bases`` entries to write for the chosen airfields.

    An airfield already in the collection keeps its alias — the channel lists refer to it — and any
    other key the author set on it (``color``, ``priority``…), and gets the reference's frequencies and
    title. A new one is aliased ``Base-<DCS name>``: a bare name could be shadowed by an older copy of
    the same airfield in the mission's ``airports-<theatre>`` collection, since an alias resolves in the
    first collection holding it. An entry that matches no chosen airfield is left as it is, and
    reported: it may be a FARP or a ship, which the reference does not cover, and deleting it would
    break every channel list naming it.

    Args:
        bases: The current collection.
        chosen: Airfields by id or name.
        reference: The theatre's reference.
        theatre: For the error message.

    Returns:
        The entries to write (alias -> ``{title, freqs, <kept keys>}``, in the order chosen), and the
        aliases left untouched.

    Raises:
        ValueError: An airfield is not in the reference — it would need a frequency nobody captured.
    """
    unknown = [str(k) for k in chosen if _resolve_key(k, reference) is None]
    if unknown:
        raise ValueError(
            f"not in the DCS reference for {theatre}: {', '.join(unknown)}. A base channel only carries "
            "a frequency DCS declares; list the airfields with `veaf-tools content airfield-channels`."
        )
    names = [str(e["name"]) for e in reference.values()]
    planned: dict[str, dict[str, Any]] = {}
    for key in chosen:
        entry = reference[_resolve_key(key, reference)]  # type: ignore[index]
        alias = match_existing(bases, str(entry["name"]), names) or f"Base-{entry['name']}"
        existing = bases.get(alias)
        kept = {k: v for k, v in existing.items() if k not in ("title", "freqs")} if isinstance(existing, dict) else {}
        planned[alias] = {
            "title": channel_title(str(entry["name"]), entry.get("tacan")),
            "freqs": {b: entry[b] for b in _BANDS if b in entry},
            **kept,
        }
    return planned, [str(a) for a in bases if str(a) not in planned]


def _indent(line: str) -> int:
    """Count the leading spaces of a line.

    Args:
        line: One line of the file.

    Returns:
        The number of leading spaces.
    """
    return len(line) - len(line.lstrip(" "))


def _is_content(line: str) -> bool:
    """Tell a line carrying YAML from a blank or comment line.

    Args:
        line: One line of the file.

    Returns:
        ``True`` when the line is neither blank nor a comment.
    """
    stripped = line.strip()
    return bool(stripped) and not stripped.startswith("#")


_KEY_RE = re.compile(r"""^\s*(?:"([^"]*)"|'([^']*)'|([^#'"{}\[\]][^:#]*?))\s*:(?:\s|$)""")


def _key_of(line: str) -> str | None:
    """Return the mapping key a line opens.

    Args:
        line: One line of the file.

    Returns:
        The key, unquoted, or ``None`` when the line opens no key.
    """
    match = _KEY_RE.match(line)
    if not match:
        return None
    return next(group for group in match.groups() if group is not None)


def _inline_value(line: str) -> str:
    """Return what follows a key's colon on its own line, comment excluded.

    Args:
        line: A line opening a key.

    Returns:
        The inline value (``""`` for a block key, ``"{}"`` for an empty flow mapping).
    """
    after = line.split(":", 1)[1] if ":" in line else ""
    return re.sub(r"\s+#.*$", "", after).strip()


def _open_block(lines: list[str], index: int, key: str, newline: str) -> None:
    """Turn ``key: {}`` into a block key ``key:`` in place, so entries can go under it.

    Args:
        lines: The file's lines.
        index: The line opening the key.
        key: The key's name, for the error message.
        newline: The file's line ending.

    Raises:
        ValueError: The key holds a non-empty flow mapping, which cannot be edited line by line.
    """
    value = _inline_value(lines[index])
    if value in ("", "{}"):
        if value:
            lines[index] = f"{' ' * _indent(lines[index])}{key}:{newline}"
        return
    raise ValueError(f"`{key}` is written on one line ({value[:40]}); write it as a block to let the tool edit it")


def _render_entry(
    alias: str, channel: dict[str, Any], indent: int, spaced: bool, newline: str, comment: str
) -> list[str]:
    """Render one ``bases`` entry the way the file writes its others.

    Args:
        alias: The entry's key.
        channel: ``{title, freqs}``, plus any key kept from the existing entry.
        indent: The entry's indentation.
        spaced: Whether the file writes flow mappings ``{ a: 1 }`` rather than ``{a: 1}``.
        newline: The file's line ending.
        comment: An end-of-line comment to keep on the key line (``""`` for none).

    Returns:
        The entry's lines, line endings included.
    """
    pad = " " * indent
    freqs = ", ".join(f"{band}: {value}" for band, value in channel["freqs"].items())
    flow = f"{{ {freqs} }}" if spaced else f"{{{freqs}}}"
    rendered = [
        f"{pad}{yaml_scalar(alias)}:{comment}{newline}",
        f"{pad}  title: {yaml_scalar(str(channel['title']))}{newline}",
        f"{pad}  freqs: {flow}{newline}",
    ]
    for key, value in channel.items():
        if key not in ("title", "freqs"):
            dumped = yaml.safe_dump(value, allow_unicode=True, default_flow_style=True, width=10_000)
            rendered.append(f"{pad}  {yaml_scalar(str(key))}: {dumped.strip().removesuffix('...').strip()}{newline}")
    return rendered


def rewrite_bases_text(text: str, planned: dict[str, dict[str, Any]]) -> str:
    """Write the planned entries into the ``bases`` collection of a ``presets.yaml``, as text.

    Only the lines of the entries written change: every other line, comment, quoting style and line
    ending of the file is kept byte for byte — a round-trip YAML dump rewrote some forty lines of a real
    mission to change twelve entries. An existing entry is replaced in place; a new one is appended at
    the end of the collection; the collection, or ``channels_collection`` itself, is created at the end
    of its parent when missing, and an empty ``{}`` on either is opened into a block.

    Args:
        text: The whole file.
        planned: Output of :func:`plan_bases`.

    Returns:
        The new text (equal to *text* when nothing changes).

    Raises:
        ValueError: ``channels_collection`` or ``bases`` is a non-empty one-line flow mapping.
    """
    newline = "\r\n" if "\r\n" in text else "\n"
    spaced = "{ " in text
    lines = text.splitlines(keepends=True)
    if lines and not lines[-1].endswith(("\n", "\r")):
        lines[-1] += newline

    top = next((i for i, line in enumerate(lines) if re.match(r"^channels_collection\s*:", line)), None)
    if top is None:
        block = [f"channels_collection:{newline}", f"  {BASES_COLLECTION}:{newline}"]
        for alias, channel in planned.items():
            block += _render_entry(alias, channel, 4, spaced, newline, "")
        return "".join(lines + block)
    _open_block(lines, top, "channels_collection", newline)
    section_end = next(
        (i for i in range(top + 1, len(lines)) if _is_content(lines[i]) and _indent(lines[i]) == 0), len(lines)
    )
    children = [i for i in range(top + 1, section_end) if _is_content(lines[i])]
    child_indent = _indent(lines[children[0]]) if children else 2
    start = next(
        (i for i in children if _indent(lines[i]) == child_indent and _key_of(lines[i]) == BASES_COLLECTION), None
    )
    if start is None:
        insert_at = (children[-1] + 1) if children else top + 1
        block = [f"{' ' * child_indent}{BASES_COLLECTION}:{newline}"]
        for alias, channel in planned.items():
            block += _render_entry(alias, channel, child_indent + 2, spaced, newline, "")
        return "".join(lines[:insert_at] + block + lines[insert_at:])
    _open_block(lines, start, BASES_COLLECTION, newline)

    end = next(
        (i for i in range(start + 1, section_end) if _is_content(lines[i]) and _indent(lines[i]) <= child_indent),
        section_end,
    )
    content = [i for i in range(start + 1, end) if _is_content(lines[i])]
    entry_indent = _indent(lines[content[0]]) if content else child_indent + 2
    keys = [i for i in content if _indent(lines[i]) == entry_indent and _key_of(lines[i]) is not None]
    spans: dict[str, tuple[int, int]] = {}
    for n, i in enumerate(keys):
        stop = keys[n + 1] if n + 1 < len(keys) else end
        last = max(j for j in range(i, stop) if j == i or _is_content(lines[j]))
        spans[str(_key_of(lines[i]))] = (i, last + 1)

    replacements: dict[int, tuple[int, list[str]]] = {}
    appended: list[str] = []
    for alias, channel in planned.items():
        if alias in spans:
            first, stop = spans[alias]
            comment_match = re.search(r"\s+#.*$", lines[first].rstrip("\r\n"))
            comment = comment_match.group(0) if comment_match else ""
            replacements[first] = (stop, _render_entry(alias, channel, entry_indent, spaced, newline, comment))
        else:
            appended += _render_entry(alias, channel, entry_indent, spaced, newline, "")
    out: list[str] = []
    i = 0
    tail = (content[-1] + 1) if content else start + 1
    while i < len(lines):
        if i == tail and appended:
            out += appended
        if i in replacements:
            stop, rendered = replacements[i]
            out += rendered
            i = stop
            continue
        out.append(lines[i])
        i += 1
    if tail >= len(lines) and appended:
        out += appended
    return "".join(out)


def referenced_aliases(presets: dict[str, Any]) -> set[str]:
    """Collect every channel alias a ``channel_lists`` entry names.

    Args:
        presets: The parsed ``presets.yaml``.

    Returns:
        The aliases in use on some radio.
    """
    names: set[str] = set()
    for side in (presets.get("channel_lists") or {}).values():
        for radio in (side or {}).values():
            for value in (radio or {}).values():
                if isinstance(value, str):
                    names.add(value)
                elif isinstance(value, dict) and isinstance(value.get("channel"), str):
                    names.add(value["channel"])
    return names


def load_warehouses_config(folder: Path) -> dict[str, Any]:
    """Read a mission folder's ``src/warehouses.yaml``.

    Args:
        folder: The mission folder.

    Returns:
        The parsed file, ``{}`` when absent or empty.
    """
    path = folder / "src" / "warehouses.yaml"
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _open(folder: Path) -> tuple[DcsMission, str, dict[int, dict[str, Any]], Path]:
    """Load what both entry points need from a mission folder.

    Args:
        folder: The mission folder.

    Returns:
        The mission, its theatre, the theatre's reference and the ``src/presets.yaml`` path.

    Raises:
        ValueError: The theatre has no airfield in the reference.
    """
    from mission_tools.miz_tools import read_mission_folder

    mission = read_mission_folder(folder)
    theatre = mission.theatre_content or ""
    reference = load_reference(theatre)
    if not reference:
        raise ValueError(f"no airfield frequency is known for theatre '{theatre or '?'}'")
    return mission, theatre, reference, folder / "src" / "presets.yaml"


def _read_presets(path: Path) -> tuple[str, dict[str, Any]]:
    """Read a ``presets.yaml`` as text and as data.

    Args:
        path: The file.

    Returns:
        Its exact text (line endings kept) and its parsed content (``{}`` when absent).
    """
    if not path.is_file():
        return "", {}
    with open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    return text, yaml.safe_load(text) or {}


def describe_airfield_channels(folder: Path, include_neutral: bool = False) -> dict[str, Any]:
    """List, ranked, the airfields a mission uses and the frequencies DCS gives them. Read-only.

    Args:
        folder: The mission folder.
        include_neutral: Also list the airfields no side holds.

    Returns:
        ``{theatre, candidates, bases_channels, on_a_radio}`` — the last two say what the mission's
        ``bases`` collection already holds and which of its aliases a channel list uses.
    """
    mission, theatre, reference, presets_path = _open(folder)
    _text, presets = _read_presets(presets_path)
    bases = dict((presets.get("channels_collection") or {}).get(BASES_COLLECTION) or {})
    candidates = list_candidates(mission, load_warehouses_config(folder), bases, reference, include_neutral)
    used = referenced_aliases(presets)
    return {
        "theatre": theatre,
        "candidates": [c.as_dict() for c in candidates],
        "bases_channels": sorted(str(a) for a in bases),
        "on_a_radio": sorted(str(a) for a in bases if str(a) in used),
    }


def apply_airfield_channels(folder: Path, airfields: list[str | int]) -> dict[str, Any]:
    """Write the chosen airfields into the mission's ``bases`` collection, with DCS's frequencies.

    Only the lines of the entries written change (see :func:`rewrite_bases_text`); the tactical and
    flight channels and the channel lists are left as they are. Running it twice with the same choice
    changes nothing the second time. The file is backed up before it is overwritten.

    Args:
        folder: The mission folder.
        airfields: Airfields by DCS name or id.

    Returns:
        ``{written, channels, untouched, not_on_a_radio}``: whether the file changed, the aliases
        written, the existing aliases left as they were, and the written ones no channel list uses yet.

    Raises:
        ValueError: No airfield given, or one the reference does not know.
        FileNotFoundError: The folder has no ``src/presets.yaml``.
    """
    from mission_tools.miz_backup import backup_before_write

    if not airfields:
        raise ValueError("no airfield chosen")
    _mission, theatre, reference, presets_path = _open(folder)
    if not presets_path.is_file():
        raise FileNotFoundError(f"no src/presets.yaml in {folder}")
    text, presets = _read_presets(presets_path)
    bases = dict((presets.get("channels_collection") or {}).get(BASES_COLLECTION) or {})
    planned, untouched = plan_bases(bases, airfields, reference, theatre)
    updated = rewrite_bases_text(text, planned)
    written = updated != text
    if written:
        backup_before_write(presets_path)
        with open(presets_path, "w", encoding="utf-8", newline="") as handle:
            handle.write(updated)
    used = referenced_aliases(presets)
    return {
        "written": written,
        "channels": list(planned),
        "untouched": untouched,
        "not_on_a_radio": [a for a in planned if a not in used],
    }
