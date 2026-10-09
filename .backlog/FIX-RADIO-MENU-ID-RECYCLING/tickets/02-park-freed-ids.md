# 02 — Park each freed id on an inert command

Status: ✅ done

Measured 2026-10-09: right after `removeItem`, a command added for a group that does not exist takes the freed id, and a stale click on the removed entry fires it.

## Done when

- Each removal is followed by one inert command for `veafRadio.PARKING_GROUP_ID`, a group id no player can hold, with a unique label.
- The inert command does nothing but log at debug level.
- A Lua test proves the order: remove, then park, before any add of the same render.
