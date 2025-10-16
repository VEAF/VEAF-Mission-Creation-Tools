import re

KEY_WORDS = [
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"
]

# Create a dictionary for the order of priority keys
PRIORITY: dict[str, int] = {key.lower(): idx for idx, key in enumerate(["id", "groupId", "unitId", "zoneId", "name", "type", "skill", "task"])}

def _sort(list_to_sort: list[str]) -> list[str]:
    """
    Sorts a list of strings:
    - Alphabetically ignoring case for elements not present in PRIORITY
    - Elements present in PRIORITY are placed according to their position in this list
    
    Args:
        list_to_sort: List to sort
    
    Returns:
        Sorted list according to the criteria
    """
    
    def sort_key(item) -> tuple:
        _item = item.lower() if isinstance(item, str) else item

        # If the element is in keys_sort_order, use its priority
        return (0, PRIORITY[_item], _item) if _item in PRIORITY else (1, 0, _item)

    # check that the parameter is indeed a list
    if not isinstance(list_to_sort, list): return list_to_sort

    return sorted(list_to_sort, key=sort_key)

def _sort_by_id(list_to_sort: list):

    def _key_by_id(item):
        if not isinstance(item, dict): return item
        if item.get("id", ""): return item["id"]

    # check that the parameter is indeed a list
    if not isinstance(list_to_sort, list): return list_to_sort

    # check that all the elements in the list are dictionaries with an "id" key
    first_type = type(list_to_sort[0])
    if first_type != dict: return list_to_sort
    if not all(isinstance(item, first_type) for item in list_to_sort): return list_to_sort

    # sort the list by the "id" value of each of its entries
    return sorted(list_to_sort, key=_key_by_id)

def __serialize(var, encoding, indent, level, always_provide_keyname=False, sort=False, parent_key=None):
    parts = []
    if var is None:
        parts.append("nil")
    elif isinstance(var, bool):
        if var:
            parts.append("true")
        else:
            parts.append("false")
    elif isinstance(var, (int, float)):
        parts.append(str(var))
    elif isinstance(var, str):
        parts.extend(
            (
                '"',
                var.encode(encoding).replace(b"\\", b"\\\\").replace(b'"', b'\\"').replace(b"\n", b"\\\n").decode(encoding),
                '"',
            )
        )
    elif isinstance(var, (list, dict)):
        # calc lua table entries
        entries = []
        if isinstance(var, list):
            if parent_key in ["country"] and sort:
                sorted_var = _sort_by_id(var)
                entries.extend([i + 1, sorted_var[i]] for i in range(len(sorted_var)))
            else:
                entries.extend([i + 1, var[i]] for i in range(len(var)))
        elif isinstance(var, dict):
            sorted_keys = _sort(list_to_sort=list(var.keys())) if sort else var.keys()
            entries.extend([k, var[k]] for k in sorted_keys)
        # build lua table parts
        parts.append("{")
        s_tab_equ = "="

        # process indent
        if indent is not None:
            s_tab_equ = " = "
            if entries:
                parts.append("\n")

        # prepare for iterator
        nohash = not always_provide_keyname
        lastkey = None
        lastval = None
        hasval = False
        for kv in entries:
            key = kv[0]
            val = kv[1]
            # judge if this is a pure list table
            if nohash and (
                not isinstance(key, int)
                or (
                    lastval is None and key != 1
                )  # first loop and index is not 1 : hash table
                or (
                    lastkey is not None and lastkey + 1 != key
                )  # key is not continuously
            ):
                nohash = False
            # process to insert to table
            # insert indent
            if indent is not None:
                parts.append(indent * (level + 1))
            # insert key
            if nohash:  # pure list: do not need a key
                pass
            elif isinstance(key, str) and key not in KEY_WORDS and re.match(
                r"^[a-zA-Z_][a-zA-Z0-9_]*$", key
            ):  # -> a = val
                parts.extend(
                    (
                        key, 
                        s_tab_equ
                    )
                )
            else:  # -> [10010] = val # [".start with or contains special char"] = val
                parts.extend(
                    (
                        "[",
                        __serialize(key, encoding, indent, level + 1, always_provide_keyname=always_provide_keyname, sort=sort),
                        "]",
                        s_tab_equ,
                    )
                )
            parts.extend(
                (
                    __serialize(val, encoding, indent, level + 1, always_provide_keyname=always_provide_keyname,sort=sort, parent_key=key),
                    ",",
                )
            )
            if indent is not None:
                parts.append("\n")
            lastkey = key
            lastval = val
            hasval = True

        # remove last `,` if no indent
        if indent is None and hasval:
            parts.pop()

        # insert `}` with indent
        if indent is not None and entries:
            parts.append(indent * level)
        parts.append("}")

    return "".join(parts)


def serialize(var, encoding="utf-8", indent=None, indent_level=0, always_provide_keyname=False, sort=False):
    """Serialize variable to lua formatted data string.

    Args:
        var (number, int, float, str, dict, list): variable you want to serialize
        encoding (str, optional): target encoding, will affect string components escaping logic. Defaults to "utf-8".
        indent (str, optional): indent string, such as '\\t'. Defaults to None, means no indention.
        indent_level (int, optional): current indent level. Defaults to 0.

    Returns:
        string: serialized lua formatted data string
    """
    if isinstance(var, tuple):
        res = []
        res.extend(__serialize(item,encoding,indent,indent_level,always_provide_keyname=always_provide_keyname,sort=sort) for item in var)
        spliter = ","
        if indent is not None:
            spliter = spliter + "\n" + indent * indent_level
        return spliter.join(res)
    return __serialize(var, encoding, indent, indent_level, always_provide_keyname=always_provide_keyname, sort=sort)
