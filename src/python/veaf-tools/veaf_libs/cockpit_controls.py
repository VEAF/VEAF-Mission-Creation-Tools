"""Read an aircraft's clickable cockpit controls out of its DCS module.

A guided-checklist step needs three technical facts about a control: the element name to
box, the animation argument to read, and the value that means "in position". All three
live in Lua inside a DCS installation — ``clickabledata.lua`` for the elements and
``clickable_defs.lua`` for the prototypes they are built from. This turns them into data
the tools can query with DCS nowhere in sight.

Measured: 284 elements on the F-16C, 470 on the A-10C II, 478 on the AH-64D, 360 on the
F-14B. Naming the positions in the hint, though, is a recent ED habit rather than a rule —
127 of the F-16C's controls do it, 123 of the AH-64D's, 8 of the A-10C's, and none at all
of the F-14's. A caller cannot assume the names are there.

**What this deliberately does not do: decide which position is which value.** A hint reads
``MAIN PWR Switch, MAIN PWR/BATT/OFF`` and the switch runs +1 / 0 / −1 — descending — while
``DIGITAL BACKUP Switch, OFF/BACKUP`` runs 0 / 1, ascending. Nothing in the source says
which way round a given hint goes, so the index records the hint's own order and leaves
the mapping to a caller that can refuse, ask, or measure it in game.

See ``.backlog/FEAT-ASSIST-AUTHORING/tickets/01-control-index.md``.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

#: ``elements["NAME"] = prototype(_("hint"), …)`` — the shape every clickable element has,
#: give or take the dialect each module writes it in. The AH-64D, a two-seater, names the
#: crew station before the hint (``mpd_button(CREW.PLT, _('…'), …)``) and quotes it with
#: apostrophes; the A-10C's UFC keypad passes a bare ``""``. So anything up to the hint is
#: allowed and ignored, both quote styles are accepted, and the ``_()`` around the hint is
#: optional — the argument is looked for after it either way.
_ELEMENT_RE = re.compile(
    r'^elements\[\s*"(?P<element>[^"]+)"\s*\]\s*=\s*(?P<prototype>\w+)\('
    r"""[^)]*?(?:_\(\s*)?["'](?P<hint>[^"']*)["']\s*\)?\s*,(?P<args>.*)$""",
    re.MULTILINE,
)

#: Any element the file builds, whatever shape the call takes — the denominator the skip
#: count is measured against. ``elements["X"].sound = {…}`` sets a property and is not one.
_ASSIGNMENT_RE = re.compile(r'^elements\[\s*"[^"]+"\s*\]\s*=\s*\w+\(', re.MULTILINE)

#: The call's remaining arguments, split shallowly — enough to find the numeric ones
#: without parsing Lua. Nested tables are rare here and only follow the argument.
_CALL_ARG_RE = re.compile(r"[^,()]+|\([^()]*\)")

#: ``function name(a, b, …)`` — one prototype. ``local`` counts: ``button_prototype``,
#: which every button delegates to, is declared that way.
_PROTOTYPE_RE = re.compile(r"^(?:local\s+)?function\s+(?P<name>\w+)\s*\((?P<params>[^)]*)\)", re.MULTILINE)

#: A literal ``arg_lim = {{a,b}, …}`` inside a prototype body.
_ARG_LIM_LITERAL_RE = re.compile(r"arg_lim\s*=\s*\{\s*\{\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\}")

#: ``arg_lim = {someLocal, someLocal}`` plus ``local someLocal = someLocal_ or {a,b}``.
_ARG_LIM_VAR_RE = re.compile(r"arg_lim\s*=\s*\{\s*(\w+)\s*[,}]")

#: Prototype families whose control has **no readable position**, whatever the environment:
#: a spring-loaded switch is back at neutral before any poll, and a button is not a
#: position at all. A step on one of these has to be pilot-confirmed.
_SPRING_PREFIX = "springloaded"
_BUTTON_MARKERS = ("button",)


@dataclass(frozen=True)
class ControlPrototype:
    """One constructor from ``clickable_defs.lua``.

    Attributes:
        name: The Lua function name, e.g. ``default_3_position_tumb``.
        arg_lim: The ``[min, max]`` the animation argument runs between, when the
            prototype fixes it. ``None`` when it depends on the call (a multi-position
            knob) or cannot be read.
        readable: Whether a control built from it holds a position that can be read back.
    """

    name: str
    arg_lim: tuple[float, float] | None
    readable: bool


@dataclass(frozen=True)
class CockpitControl:
    """One clickable element of a cockpit.

    Attributes:
        element: The element name, which is also what ``a_cockpit_highlight`` boxes.
        argument: Its animation argument.
        hint: The label DCS shows on hover, e.g. ``MAIN PWR Switch, MAIN PWR/BATT/OFF``.
        prototype: The constructor it was built from.
        positions: Position names as the hint lists them, **in hint order** — which is
            not value order, see the module docstring.
        arg_lim: The window the argument runs between, when known.
        readable: Whether its position can be read back.
        command: The cockpit command the control drives, e.g. ``elec_commands.MainPwrSw``.
            It is what ties the control to the aircraft's input bindings.
        valued_positions: Positions with the value each one sets, recovered from those
            bindings. **This is the field to resolve a step against**: unlike
            ``positions`` it is not a guess about ordering, and unlike ``positions`` it
            exists on aircraft whose hints name nothing.
    """

    element: str
    argument: int
    hint: str
    prototype: str
    positions: list[str] = field(default_factory=list)
    arg_lim: tuple[float, float] | None = None
    readable: bool = True
    command: str = ""
    valued_positions: list[ControlPosition] = field(default_factory=list)


def _is_readable(prototype: str) -> bool:
    """Whether a control built from *prototype* holds a position worth reading."""
    lowered = prototype.lower()
    if lowered.startswith(_SPRING_PREFIX):
        return False
    return not any(marker in lowered for marker in _BUTTON_MARKERS)


def parse_prototypes(defs_lua: str) -> dict[str, ControlPrototype]:
    """Parse the constructors of a ``clickable_defs.lua``.

    Args:
        defs_lua: The full text of the file.

    Returns:
        Prototypes by name. A prototype whose window depends on its call arguments — a
        multi-position knob — comes back with ``arg_lim=None`` rather than a guess.
    """
    prototypes: dict[str, ControlPrototype] = {}
    bodies: dict[str, str] = {}
    starts = [(match.group("name"), match.start()) for match in _PROTOTYPE_RE.finditer(defs_lua)]
    for index, (name, start) in enumerate(starts):
        end = starts[index + 1][1] if index + 1 < len(starts) else len(defs_lua)
        body = defs_lua[start:end]

        arg_lim: tuple[float, float] | None = None
        literal = _ARG_LIM_LITERAL_RE.search(body)
        if literal:
            arg_lim = (float(literal.group(1)), float(literal.group(2)))
        else:
            variable = _ARG_LIM_VAR_RE.search(body)
            if variable:
                # `local arg_limit = arg_limit_ or {-1,1}` — the default is the window
                # unless the call overrides it, which almost nothing does.
                default = re.search(
                    rf"local\s+{re.escape(variable.group(1))}\s*=.*?or\s*\{{\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\}}",
                    body,
                )
                if default:
                    arg_lim = (float(default.group(1)), float(default.group(2)))
        prototypes[name] = ControlPrototype(name=name, arg_lim=arg_lim, readable=_is_readable(name))
        bodies[name] = body

    return _resolve_delegations(prototypes, bodies)


#: ``local element = default_3_position_tumb(hint_, …)`` — a variant that adds a sound and
#: returns what a base prototype built. Half the F-16C's controls are built from one, so
#: not following the call leaves their window unknown for no reason.
_DELEGATION_RE = re.compile(r"=\s*(\w+)\s*\(\s*hint_")


def _resolve_delegations(
    prototypes: dict[str, ControlPrototype], bodies: dict[str, str]
) -> dict[str, ControlPrototype]:
    """Give a variant the window of the prototype it delegates to.

    Readability is **not** inherited: it comes from the variant's own name, because
    ``short_way_button`` delegates to a prototype with a perfectly good window and is
    still a button with no position to read.
    """
    resolved = dict(prototypes)
    for name, prototype in prototypes.items():
        if prototype.arg_lim is not None:
            continue
        seen: set[str] = {name}
        current = name
        for _ in range(4):  # a variant of a variant is as deep as this goes
            match = _DELEGATION_RE.search(bodies.get(current, ""))
            if match is None:
                break
            target = match.group(1)
            if target in seen or target not in prototypes:
                break
            seen.add(target)
            if prototypes[target].arg_lim is not None:
                resolved[name] = ControlPrototype(
                    name=name, arg_lim=prototypes[target].arg_lim, readable=prototype.readable
                )
                break
            current = target
    return resolved


#: One keyboard/joystick binding: the command it drives, the value it sets, its label.
#: ``{down = elec_commands.MainPwrSw, …, value_down = -1.0, name = _('MAIN PWR Switch - OFF')}``.
#: This is the **only** source in a DCS install that says which position is which value —
#: a hint lists position names in its own order, which is not value order. Bindings that
#: also carry ``up =`` are two-way combos ("MAIN PWR/BATT"), not positions, and are left out.
_BINDING_RE = re.compile(
    r"\{\s*down\s*=\s*(?P<command>[\w.]+)\s*,(?P<body>[^}]*?)"
    r"name\s*=\s*_\(\s*(?P<quote>['\"])(?P<label>.*?)(?P=quote)\s*\)",
    re.DOTALL,
)
_BINDING_VALUE_RE = re.compile(r"value_down\s*=\s*(-?[\d.]+)")
_BINDING_UP_RE = re.compile(r"(?<!value_)\bup\s*=")


@dataclass(frozen=True)
class ControlPosition:
    """One position of a control: what it is called, and the value it sets.

    Attributes:
        name: The position as the aircraft's own bindings name it — ``OFF``, ``BATT``.
        value: The animation-argument value it corresponds to.
    """

    name: str
    value: float


def parse_input_positions(input_lua: str) -> dict[str, list[ControlPosition]]:
    """Parse an aircraft's input bindings into named positions per command.

    Args:
        input_lua: Text of one or more ``Input/**/default.lua`` files, concatenated.

    Returns:
        Command name -> its positions, in binding order. A command with fewer than two
        bindings yields nothing: a single binding is a keystroke, not a set of positions.
    """
    by_command: dict[str, list[tuple[float, str]]] = {}
    for match in _BINDING_RE.finditer(input_lua):
        body = match.group("body")
        if _BINDING_UP_RE.search(body):
            continue
        value = _BINDING_VALUE_RE.search(body)
        if value is None:
            continue
        by_command.setdefault(match.group("command"), []).append((float(value.group(1)), match.group("label")))

    positions: dict[str, list[ControlPosition]] = {}
    for command, bindings in by_command.items():
        if len(bindings) < 2:
            continue
        names = _strip_common_prefix([label for _value, label in bindings])
        seen: set[float] = set()
        kept: list[ControlPosition] = []
        for (setting, _label), name in zip(bindings, names, strict=True):
            if name and setting not in seen:
                seen.add(setting)
                kept.append(ControlPosition(name=name, value=setting))
        if len(kept) > 1:
            positions[command] = kept
    return positions


def _strip_common_prefix(labels: list[str]) -> list[str]:
    """Drop the control's own name from a set of binding labels, leaving the positions.

    ``MAIN PWR Switch - OFF`` / ``… - BATT`` share a prefix down to the separator;
    Heatblur writes ``Hydraulic Transfer Pump Switch NORMAL`` with no separator at all.
    Cutting at the last shared word handles both without knowing which style is in use.
    """
    split = [label.split() for label in labels]
    shared = 0
    while all(len(words) > shared + 1 for words in split) and len({words[shared] for words in split}) == 1:
        shared += 1
    return [" ".join(words[shared:]).strip(" -/:").strip() for words in split]


def _positions_from_hint(hint: str) -> list[str]:
    """Split the position names out of a hint, or return nothing.

    ``MAIN PWR Switch, MAIN PWR/BATT/OFF`` names its positions after the comma. A hint
    with no comma, or none after it, describes a control whose positions are unnamed.
    """
    if "," not in hint:
        return []
    tail = hint.split(",", 1)[1].strip()
    if "/" not in tail:
        return []
    return [part.strip() for part in tail.split("/") if part.strip()]


#: ``cockpit_args = { NAME = 1234, … }`` — a table of named animation arguments. Heatblur
#: writes ``cockpit_args.HYD_ISOLATION_Switch`` where ED writes ``629``, so without this
#: the F-14 comes back with a tenth of its cockpit.
_ARG_TABLE_RE = re.compile(r"^(?P<name>\w+)\s*=\s*\{(?P<body>.*?)^\}", re.MULTILINE | re.DOTALL)
_ARG_CONSTANT_RE = re.compile(r"^\s*(?P<name>\w+)\s*=\s*(?P<value>\d+)\s*,", re.MULTILINE)

#: The command argument of an element's call: the second qualified reference, after the
#: device. ``default_3_position_tumb(_("…"), devices.ELEC_INTERFACE, elec_commands.MainPwrSw, 510)``.
_COMMAND_RE = re.compile(r"\w+\.\w+")


def _command_of(call_args: str) -> str:
    """Return the command an element's call drives, or an empty string.

    The device is the first qualified reference of the call and the command the second;
    a module that passes neither simply has no binding to tie the control to.
    """
    references = [
        piece.strip() for piece in _CALL_ARG_RE.findall(call_args) if _COMMAND_RE.fullmatch(piece.strip()) is not None
    ]
    return references[1] if len(references) > 1 else ""


#: ``cockpit_args.NAME`` — a reference into one of those tables.
_QUALIFIED_REF_RE = re.compile(r"^(?P<table>\w+)\.(?P<name>\w+)$")


def parse_argument_constants(args_lua: str) -> dict[str, dict[str, int]]:
    """Parse the named-argument tables of a module's ``draw_args.lua``.

    Args:
        args_lua: Text of the file, or an empty string when the module has none.

    Returns:
        Table name -> constant name -> value. Keeping the table name means a reference is
        only resolved against the table it actually names, so a constant that happens to
        share a name with a device or a command cannot be picked up by mistake.
    """
    tables: dict[str, dict[str, int]] = {}
    for table in _ARG_TABLE_RE.finditer(args_lua):
        constants = {c.group("name"): int(c.group("value")) for c in _ARG_CONSTANT_RE.finditer(table.group("body"))}
        if constants:
            tables[table.group("name")] = constants
    return tables


def _argument_of(call_args: str, constants: dict[str, dict[str, int]]) -> int | None:
    """Return a call's animation argument: the first bare integer or resolvable constant.

    Args:
        call_args: The call's arguments, hint excluded.
        constants: Named-argument tables, from :func:`parse_argument_constants`.

    Returns:
        The argument, or ``None`` when the call names it in a way this cannot follow.
    """
    for piece in _CALL_ARG_RE.findall(call_args):
        stripped = piece.strip()
        if stripped.isdigit():
            return int(stripped)
        reference = _QUALIFIED_REF_RE.match(stripped)
        if reference is not None:
            table = constants.get(reference.group("table"))
            if table is not None and reference.group("name") in table:
                return table[reference.group("name")]
    return None


#: ``multiposition_switch(hint, device, command, arg, count, delta, inversed, min, …)``.
#: Its window is computed from the call rather than fixed by the prototype, and these are
#: the knobs a checklist actually names — ENGINE FEED, IFF MASTER, ANTI-COLL. Worth the
#: special case; without it every multi-position knob comes back windowless.
_MULTIPOSITION = "multiposition_switch"


def _multiposition_window(call_args: str) -> tuple[float, float] | None:
    """Compute ``[min, min + delta * (count - 1)]`` from a multi-position switch's call."""
    numbers: list[float] = []
    for piece in _CALL_ARG_RE.findall(call_args):
        stripped = piece.strip()
        try:
            numbers.append(float(stripped))
        except ValueError:
            # A named constant (NOT_INVERSED, anim_speed_default) holds a position in the
            # signature, so stop rather than shift everything left by one.
            if numbers:
                break
    # argument, count, delta — and min, when the call bothers to give it.
    if len(numbers) < 3:
        return None
    _, count, delta = numbers[0], numbers[1], numbers[2]
    minimum = numbers[3] if len(numbers) > 3 else 0.0
    if count < 2:
        return None
    return (minimum, minimum + delta * (count - 1))


def parse_controls(
    clickabledata_lua: str,
    prototypes: dict[str, ControlPrototype],
    constants: dict[str, dict[str, int]] | None = None,
    input_positions: dict[str, list[ControlPosition]] | None = None,
) -> list[CockpitControl]:
    """Parse the clickable elements of a ``clickabledata.lua``.

    Args:
        clickabledata_lua: The full text of the file.
        prototypes: The constructors, from :func:`parse_prototypes`.
        constants: Named-argument tables, from :func:`parse_argument_constants`. Only
            needed by modules that name their arguments instead of writing them out.
        input_positions: Named positions per command, from :func:`parse_input_positions`.

    Returns:
        One entry per element whose argument could be recovered, in file order. An element
        the pattern cannot make sense of is skipped — :func:`parse_aircraft` reports how
        many, so a silent drop cannot pass for a complete index.
    """
    controls: list[CockpitControl] = []
    for match in _ELEMENT_RE.finditer(clickabledata_lua):
        argument = _argument_of(match.group("args"), constants or {})
        if argument is None:
            continue
        prototype_name = match.group("prototype")
        prototype = prototypes.get(prototype_name)
        arg_lim = prototype.arg_lim if prototype else None
        if arg_lim is None and prototype_name == _MULTIPOSITION:
            arg_lim = _multiposition_window(match.group("args"))
        command = _command_of(match.group("args"))
        controls.append(
            CockpitControl(
                command=command,
                valued_positions=(input_positions or {}).get(command, []),
                element=match.group("element"),
                argument=argument,
                hint=match.group("hint"),
                prototype=prototype_name,
                positions=_positions_from_hint(match.group("hint")),
                arg_lim=arg_lim,
                readable=prototype.readable if prototype else _is_readable(prototype_name),
            )
        )
    return controls


@dataclass(frozen=True)
class AircraftControls:
    """Every clickable control of one aircraft, plus how many elements were skipped."""

    aircraft: str
    controls: list[CockpitControl]
    skipped: int = 0


def parse_aircraft(
    aircraft: str, clickabledata_lua: str, defs_lua: str, args_lua: str = "", input_lua: str = ""
) -> AircraftControls:
    """Parse one aircraft's cockpit from the text of its Lua files.

    Args:
        aircraft: The DCS type name to record in the index.
        clickabledata_lua: Text of ``clickabledata.lua``.
        defs_lua: Text of ``clickable_defs.lua``.
        args_lua: Text of ``draw_args.lua``, for a module that names its arguments.
        input_lua: Text of the module's ``Input/**/default.lua`` files, concatenated —
            the only place a position's *value* is written down.

    Returns:
        The parsed controls, with a count of elements the pattern matched but whose
        argument could not be found.
    """
    prototypes = parse_prototypes(defs_lua)
    controls = parse_controls(
        clickabledata_lua,
        prototypes,
        parse_argument_constants(args_lua),
        parse_input_positions(input_lua),
    )
    # Counted against every element the file declares, not against the ones the pattern
    # understood: an element built in a shape this does not read has to show up here too,
    # or a partial index passes for a complete one.
    declared = len(_ASSIGNMENT_RE.findall(clickabledata_lua))
    return AircraftControls(aircraft=aircraft, controls=controls, skipped=declared - len(controls))


#: Where a module may keep its cockpit scripts, most common first. ED's own aircraft use
#: ``Cockpit/Scripts``; Heatblur's F-14 puts the same files one level up, in ``Cockpit``.
_COCKPIT_SUBDIRS = (("Cockpit", "Scripts"), ("Cockpit",))


def cockpit_scripts_folder(dcs_path: Path, module: str) -> Path:
    """Return where an aircraft module keeps its cockpit scripts.

    Args:
        dcs_path: Root of the DCS installation.
        module: Folder name under ``Mods/aircraft``.

    Returns:
        The first candidate folder holding a ``clickabledata.lua``, or the conventional
        ``Cockpit/Scripts`` when the module has none — so the caller's error message
        names the place a reader would look first.
    """
    root = dcs_path / "Mods" / "aircraft" / module
    for parts in _COCKPIT_SUBDIRS:
        candidate = root.joinpath(*parts)
        if (candidate / "clickabledata.lua").is_file():
            return candidate
    return root / "Cockpit" / "Scripts"


def read_dcs_version(dcs_path: Path) -> str:
    """Return the version of a DCS installation, for an index's provenance header.

    Args:
        dcs_path: Root of the DCS installation.

    Returns:
        The version string from ``autoupdate.cfg``, or an empty string when the file is
        missing or unreadable — an index without a version is still worth having.
    """
    config = dcs_path / "autoupdate.cfg"
    try:
        return str(json.loads(config.read_text(encoding="utf-8", errors="replace")).get("version", ""))
    except (OSError, ValueError):
        return ""


def read_aircraft(dcs_path: Path, module: str, aircraft: str, cockpit_module: str | None = None) -> AircraftControls:
    """Read one aircraft's controls straight from a DCS installation.

    Args:
        dcs_path: Root of the DCS installation.
        module: Folder name under ``Mods/aircraft``, e.g. ``F-16C``. Its input bindings
            are the ones read, since those are per-aircraft.
        aircraft: The DCS **type** name, e.g. ``F-16C_50``.
        cockpit_module: The module whose cockpit files to read, when it is not *module*.
            The F-14B(U) needs this: its own ``clickabledata.lua`` is two lines of
            ``dofile`` pointing at the F-14B's, but it ships its own bindings.

    Returns:
        The parsed controls.

    Raises:
        FileNotFoundError: when the module ships neither file.
    """
    folder = cockpit_scripts_folder(dcs_path, cockpit_module or module)
    clickabledata = folder / "clickabledata.lua"
    if not clickabledata.is_file():
        raise FileNotFoundError(f"no clickabledata.lua for module {cockpit_module or module} under {folder}")

    def read(name: str) -> str:
        path = folder / name
        return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""

    # A variant inherits the base module's bindings and adds only its differences: the
    # F-14B(U)'s own Input folders are stubs that pull the F-14B's profiles in, so reading
    # them alone yields 4 valued positions where the pair yields 87. Its own come first,
    # since the first binding of a command wins.
    bindings = read_input_bindings(dcs_path, module)
    if cockpit_module and cockpit_module != module:
        bindings = bindings + "\n" + read_input_bindings(dcs_path, cockpit_module)

    return parse_aircraft(
        aircraft,
        clickabledata.read_text(encoding="utf-8", errors="replace"),
        read("clickable_defs.lua"),
        read("draw_args.lua"),
        bindings,
    )


def read_input_bindings(dcs_path: Path, module: str) -> str:
    """Concatenate every input-binding file a module ships.

    A module spreads its bindings over several profiles — the F-14 has one per crew seat,
    each pulling the others in with ``dofile`` — and which file holds a given command is
    not predictable. Reading them all and letting the first binding of a command win costs
    nothing and misses nothing.

    Args:
        dcs_path: Root of the DCS installation.
        module: Folder name under ``Mods/aircraft``.

    Returns:
        The concatenated text, or an empty string when the module ships no bindings.
    """
    root = dcs_path / "Mods" / "aircraft" / module / "Input"
    if not root.is_dir():
        return ""
    return "\n".join(
        path.read_text(encoding="utf-8", errors="replace") for path in sorted(root.glob("*/*/default.lua"))
    )


def to_index(controls: AircraftControls, module: str, dcs_version: str = "") -> dict:
    """Render the parsed controls as the mapping written to the index file."""
    return {
        "aircraft": controls.aircraft,
        "module": module,
        "source": "clickabledata.lua",
        "dcs_version": dcs_version,
        "controls": {
            control.element: {
                "argument": control.argument,
                "hint": control.hint,
                "prototype": control.prototype,
                # Hint order, NOT value order — see the module docstring.
                "positions": control.positions,
                "command": control.command,
                # Name -> value, from the aircraft's own input bindings. Unlike
                # `positions`, this says which position IS which value.
                "values": {position.name: position.value for position in control.valued_positions},
                "range": list(control.arg_lim) if control.arg_lim else None,
                "readable": control.readable,
            }
            for control in controls.controls
        },
    }
