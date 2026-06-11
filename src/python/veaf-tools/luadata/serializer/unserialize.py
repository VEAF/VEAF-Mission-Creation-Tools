import math

try:
    from lupa.lua51 import LuaRuntime, lua_type
except ImportError:
    try:
        from lupa.lua54 import LuaRuntime, lua_type  # type: ignore[assignment]
    except ImportError:
        try:
            from lupa import LuaRuntime, lua_type  # type: ignore[assignment]  # lupa 1.x
        except ImportError:
            LuaRuntime = None  # type: ignore[assignment,misc]
            lua_type = None  # type: ignore[assignment]

from veaf_libs.logger import logger


def _unserialize(raw: str, encoding: str = "utf-8", multival: bool = False, verbose: bool = False) -> tuple:
    """Unserialize stringified lua data to python data

    Args:
        raw (str): raw lua data string
        encoding (str, optional): string encoding. Defaults to "utf-8".
        multival (bool, optional): returns tuple for supporting multiple lua values likes "return 1, 2". Defaults to False.
        verbose (bool, optional): show more verbose debug information. Defaults to False.

    Raises:
        Exception: unserialize errors

    Returns:
        tuple([*]): unserialized data
    """
    sbins = raw.encode(encoding)
    root = {"entries": [], "lualen": 0, "is_root": True}
    node = root
    stack = []
    state = "SEEK_CHILD"
    pos = 0
    slen = len(sbins)
    byte_quoting_char = None
    key = None
    escaping = False
    comment = None
    component_name = None
    errmsg = None

    def sorter(kv):
        if isinstance(kv[0], int):
            return kv[0]
        return math.inf

    def node_entries_append(node, key, val):
        node["entries"].append([key, val])
        node["entries"].sort(key=sorter)
        lualen = 0
        for kv in node["entries"]:
            if kv[0] == lualen + 1:
                lualen = lualen + 1
        node["lualen"] = lualen

    def node_to_table(node):
        if len(node["entries"]) == node["lualen"]:
            lst = []
            for kv in node["entries"]:
                lst.append(kv[1])
            return lst
        else:
            dct = {}
            for kv in node["entries"]:
                dct[kv[0]] = kv[1]
            return dct

    while pos <= slen:
        byte_current = None
        byte_current_is_space = False
        if pos < slen:
            byte_current = sbins[pos: pos + 1]
            byte_current_is_space = (
                byte_current == b" "
                or byte_current == b"\r"
                or byte_current == b"\n"
                or byte_current == b"\t"
            )
        if verbose:
            print("[step] pos", pos, byte_current, state, comment, key, node)

        if comment == "MULTILINE":
            if byte_current == b"]" and sbins[pos: pos + 2] == b"]]":
                comment = None
                pos = pos + 1
        elif comment == "INLINE":
            if byte_current == b"\n":
                comment = None
        elif state == "SEEK_CHILD":
            if byte_current is None:
                break
            if byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif not node["is_root"] and (
                (b"A" <= byte_current <= b"Z")
                or (b"a" <= byte_current <= b"z")
                or byte_current == b"_"
            ):
                state = "KEY_SIMPLE"
                pos1 = pos
            elif not node["is_root"] and byte_current == b"[":
                state = "KEY_EXPRESSION_OPEN"
            elif byte_current == b"}":
                if len(stack) == 0:
                    errmsg = (
                        "unexpected table closing, no matching opening braces found."
                    )
                    break
                prev_env = stack.pop()
                if prev_env["state"] == "KEY_EXPRESSION_OPEN":
                    key = node_to_table(node)
                    state = "KEY_END"
                elif prev_env["state"] == "VALUE":
                    node_entries_append(
                        prev_env["node"],
                        prev_env["key"],
                        node_to_table(node),
                    )
                    state = "VALUE_END"
                    key = None
                node = prev_env["node"]
            elif not byte_current_is_space:
                key = node["lualen"] + 1
                state = "VALUE"
                pos = pos - 1
        elif state == "VALUE":
            if byte_current is None:
                errmsg = "unexpected empty value."
                break
            elif byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif byte_current == b'"' or byte_current == b"'":
                state = "TEXT"
                component_name = "VALUE"
                pos1 = pos + 1
                byte_quoting_char = byte_current
            elif byte_current == b"-" or (b"0" <= byte_current <= b"9"):
                state = "INT"
                component_name = "VALUE"
                pos1 = pos
            elif byte_current == b".":
                state = "FLOAT"
                component_name = "VALUE"
                pos1 = pos
            elif byte_current == b"t" and sbins[pos: pos + 4] == b"true":
                node_entries_append(node, key, True)
                state = "VALUE_END"
                key = None
                pos = pos + 3
            elif byte_current == b"f" and sbins[pos: pos + 5] == b"false":
                node_entries_append(node, key, False)
                state = "VALUE_END"
                key = None
                pos = pos + 4
            elif byte_current == b"n" and sbins[pos: pos + 3] == b"nil":
                # Lua `nil` value: in Lua a table entry assigned nil simply does
                # not exist, so we drop the entry (do not append it) — matching
                # the original lua-execution behaviour for `country = nil` etc.
                state = "VALUE_END"
                key = None
                pos = pos + 2
            elif byte_current == b"{":
                stack.append({"node": node, "state": state, "key": key})
                state = "SEEK_CHILD"
                node = {"entries": [], "lualen": 0, "is_root": False}
        elif state == "TEXT":
            if byte_current is None:
                errmsg = "unexpected string ending: missing close quote."
                break
            if escaping:
                escaping = False
            elif byte_current == b"\\":
                escaping = True
            elif byte_current == byte_quoting_char:
                data = (
                    sbins[pos1:pos]
                    # Lua line continuation: a backslash followed by a real
                    # newline (LF, CRLF or CR) collapses to a single "\n".
                    # CRLF/CR must be handled before LF to match Lua on the
                    # Windows line endings DCS uses in briefing texts.
                    .replace(b"\\\r\n", b"\n")
                    .replace(b"\\\r", b"\n")
                    .replace(b"\\\n", b"\n")
                    .replace(b'\\"', b'"')
                    .replace(b"\\\\", b"\\")
                    .decode(encoding)
                )
                if component_name == "KEY":
                    key = data
                    state = "KEY_EXPRESSION_FINISH"
                elif component_name == "VALUE":
                    node_entries_append(node, key, data)
                    state = "VALUE_END"
                    key = None
        elif state == "INT":
            if byte_current == b"." or byte_current == b"e":
                state = "FLOAT"
            elif byte_current is None or byte_current < b"0" or byte_current > b"9":
                data = int(sbins[pos1:pos].decode(encoding))
                if component_name == "KEY":
                    key = data
                    state = "KEY_EXPRESSION_FINISH"
                    pos = pos - 1
                elif component_name == "VALUE":
                    node_entries_append(node, key, data)
                    state = "VALUE_END"
                    key = None
                    pos = pos - 1
        elif state == "FLOAT":
            if byte_current == b"e" or byte_current == b"-" or byte_current == b"+":
                pass
            elif byte_current is None or byte_current < b"0" or byte_current > b"9":
                if pos == pos1 + 1 and sbins[pos1:pos] == b".":
                    errmsg = "unexpected dot."
                    break
                else:
                    data = float(sbins[pos1:pos].decode(encoding))
                    if component_name == "KEY":
                        key = data
                        state = "KEY_EXPRESSION_FINISH"
                        pos = pos - 1
                    elif component_name == "VALUE":
                        node_entries_append(node, key, data)
                        state = "VALUE_END"
                        key = None
                        pos = pos - 1
        elif state == "VALUE_END":
            if byte_current is None:
                pass
            elif byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif byte_current == b",":
                state = "SEEK_CHILD"
            elif byte_current == b"}":
                state = "SEEK_CHILD"
                pos = pos - 1
            elif not byte_current_is_space:
                errmsg = "unexpected character."
                break
        elif state == "KEY_EXPRESSION_OPEN":
            if byte_current is None:
                errmsg = "key expression expected."
                break
            if byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif byte_current == b'"' or byte_current == b"'":
                state = "TEXT"
                component_name = "KEY"
                pos1 = pos + 1
                byte_quoting_char = byte_current
            elif byte_current == b"-" or (
                    b"0" <= byte_current <= b"9"
            ):
                state = "INT"
                component_name = "KEY"
                pos1 = pos
            elif byte_current == b".":
                state = "FLOAT"
                component_name = "KEY"
                pos1 = pos
            elif byte_current == b"t" and sbins[pos: pos + 4] == b"true":
                errmsg = "python do not support bool as dict key."
                break
            elif byte_current == b"f" and sbins[pos: pos + 5] == b"false":
                errmsg = "python do not support bool variable as dict key."
                break
            elif byte_current == b"{":
                errmsg = "python do not support lua table variable as dict key."
                break
        elif state == "KEY_EXPRESSION_FINISH":
            if byte_current is None:
                errmsg = 'unexpected end of table key expression, "]" expected.'
                break
            if byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif byte_current == b"]":
                state = "KEY_EXPRESSION_CLOSE"
            elif not byte_current_is_space:
                errmsg = 'unexpected character, "]" expected.'
                break
        elif state == "KEY_EXPRESSION_CLOSE":
            if byte_current == b"=":
                state = "VALUE"
            elif byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif not byte_current_is_space:
                errmsg = 'unexpected character, "=" expected.'
                break
        elif state == "KEY_SIMPLE":
            if not (
                (b"A" <= byte_current <= b"Z")  # type: ignore[operator]
                or (b"a" <= byte_current <= b"z")  # type: ignore[operator]
                or (b"0" <= byte_current <= b"9")  # type: ignore[operator]
                or byte_current == b"_"
            ):
                key = sbins[pos1:pos].decode(encoding)
                state = "KEY_SIMPLE_END"
                pos = pos - 1
        elif state == "KEY_SIMPLE_END":
            if byte_current_is_space:
                pass
            elif byte_current == b"-" and sbins[pos: pos + 4] == b"--[[":
                comment = "MULTILINE"
                pos = pos + 3
            elif byte_current == b"-" and sbins[pos: pos + 2] == b"--":
                comment = "INLINE"
                pos = pos + 1
            elif byte_current == b"=":
                state = "VALUE"
            elif byte_current == b"," or byte_current == b"}":
                if key == "true":
                    node_entries_append(node, node["lualen"] + 1, True)
                    state = "VALUE_END"
                    key = None
                    pos = pos - 1
                elif key == "false":
                    node_entries_append(node, node["lualen"] + 1, False)
                    state = "VALUE_END"
                    key = None
                    pos = pos - 1
                else:
                    key = None
                    errmsg = "invalid table simple key character."
                    break
        pos += 1
        if verbose:
            print("          ", pos, "    ", state, comment, key, node)

    # check if there is any errors
    if errmsg is None and len(stack) != 0:
        errmsg = 'unexpected end of table, "}" expected.'
    if errmsg is None and root["lualen"] == 0:
        errmsg = "nothing can be unserialized from input string."
    if errmsg is not None:
        pos = min(pos, slen)
        start_pos = max(0, pos - 4)
        end_pos = min(pos + 10, slen)
        err_parts = sbins[start_pos:end_pos].decode(encoding)
        err_indent = " " * (pos - start_pos)
        logger.error(message=f"Unserialize luadata failed on pos {pos}:\n    {err_parts}\n    {err_indent}^\n    {errmsg}", exception_type=ValueError)

    res = []
    for kv in root["entries"]:
        res.append(kv[1])
    if multival:
        return tuple(res)
    return res[0]


def _lua_table_to_dict(lua_table, keep_as_dict: list[str] | None = None, all_is_dict: bool = False) -> dict | list:
    # Check if a Lua table is a list
    def is_lua_list(table):
        keys = list(table.keys())
        return keys and all(isinstance(key, int) for key in keys) and sorted(keys) == list(range(1, len(keys) + 1))

    # Handle conversion
    if not(all_is_dict) and is_lua_list(lua_table):
        # Convert to Python list
        return [lua_table[i] if lua_type(lua_table[i]) != "table" else _lua_table_to_dict(lua_table[i])  # type: ignore[misc]
                for i in range(1, len(lua_table) + 1)]

    # Convert to Python dict
    py_dict = {}
    for key, value in lua_table.items():
        if lua_type(value) == "table":  # type: ignore[misc]
            # Recursively convert nested Lua tables
            value = _lua_table_to_dict(value, keep_as_dict=keep_as_dict, all_is_dict=True if (keep_as_dict and key in keep_as_dict) else all_is_dict)
        py_dict[key] = value

    return py_dict


def _apply_dict_policy(value: object, keep_as_dict: list[str] | None, all_is_dict: bool) -> object:
    """Apply the ``keep_as_dict`` / ``all_is_dict`` policy to a parsed Lua value.

    The pure-Python ``_unserialize`` state machine collapses every table to a
    list when its keys form a contiguous ``1..n`` sequence (and to an empty list
    when the table is empty). This pass reproduces, byte for byte, the behaviour
    of the former lupa-based ``_lua_table_to_dict`` so that rerouting ``.miz``
    parsing away from ``lua.execute`` keeps identical output:

    - an empty table becomes ``{}`` (Lua ``{}`` is ambiguous; the historical
      behaviour treated it as a dict);
    - once a key listed in ``keep_as_dict`` is reached, that whole subtree stays
      a dict (``all_is_dict`` propagates down);
    - the list branch intentionally drops ``keep_as_dict`` for nested values,
      matching the historical converter.

    Args:
        value: A value produced by ``_unserialize`` (dict, list, or scalar).
        keep_as_dict: Keys whose subtree must remain a dict even if list-shaped.
        all_is_dict: When ``True``, force every nested table to a dict.

    Returns:
        The value with the dict/list policy applied.
    """
    if isinstance(value, list):
        if not value:
            return {}
        if all_is_dict:
            return {i + 1: _apply_dict_policy(item, keep_as_dict, True) for i, item in enumerate(value)}
        return [_apply_dict_policy(item, None, False) for item in value]
    if isinstance(value, dict):
        return {
            key: _apply_dict_policy(item, keep_as_dict, True if (keep_as_dict and key in keep_as_dict) else all_is_dict)
            for key, item in value.items()
        }
    return value


def unserialize(raw: str, encoding: str = "utf-8", multival: bool = False, keep_as_dict: list[str] | None = None, all_is_dict: bool = False) -> dict | list:
    """Deserialize stringified Lua data to Python data, without executing Lua.

    Routes parsing through the pure-Python ``_unserialize`` state machine instead
    of ``lua.execute`` (which would run arbitrary code embedded in an untrusted
    ``.miz`` file — an arbitrary code execution vector). The output is made
    identical to the former lupa-based path by ``_apply_dict_policy``.

    Args:
        raw: Raw Lua data string (e.g. ``mission = { ... }``).
        encoding: String encoding. Defaults to ``"utf-8"``.
        multival: Return a tuple for multiple top-level values. Defaults to ``False``.
        keep_as_dict: Keys whose subtree must remain a dict even if list-shaped.
        all_is_dict: When ``True``, force every table to a dict.

    Returns:
        The parsed Python structure (a tuple when ``multival`` is ``True``).
    """
    parsed = _unserialize(raw, encoding=encoding, multival=multival)
    if multival:
        return tuple(_apply_dict_policy(value, keep_as_dict, all_is_dict) for value in parsed)  # type: ignore[return-value]
    return _apply_dict_policy(parsed, keep_as_dict, all_is_dict)  # type: ignore[return-value]
