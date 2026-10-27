# 01 — Whitelist of the text typed after a security-bypassing shortcut

Status: ⬜ ready

Some marker shortcuts are usable without the mission password (`-jtac`, `-afac`, `-light`, `-smoke`, `-longsmoke`, `-signal`, `-tacan`).
The text a player types after them must only tune that shortcut's effect.

## Done when

- A test reproduces the defect and fails before the fix.
- `VeafAlias:setAllowedOptions{…}` declares, per shortcut, the options admitted after it and their strict form; a bypass shortcut without a declared list admits no trailing text.
- Trailing text holding a VEAF keyword (`_spawn`, `_cas`…) is refused.
- A refusal is whole (nothing runs), told to the marker's author only, and the refused text is never logged.
- Unchanged: the bare shortcut, `#` coordinates and `!N` delay, calls from a script, a mission with security disabled, and the documented uses (`-jtac, laser 1511`, `-smoke, color red`, `-tacan, channel 37`).
- Checked on a server with real markers (in-game).
