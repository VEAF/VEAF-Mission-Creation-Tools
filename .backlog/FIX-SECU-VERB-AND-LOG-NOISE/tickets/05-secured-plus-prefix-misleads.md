# 05 — the `+` on a secured command never goes away

Status: ✅ done

A secured radio command is titled `"+" .. title` at build time
(`veafRadio.lua`, `_addDcsCommand`). The prefix says "this one is secured"; it does **not** track
whether the pilot may use it, and cannot — the title is fixed when the menu is built, while the
decision is taken per click, against a level that changes (an elevation lasts 120 s).

David read it the other way round on private1, 2026-09-29, and said so: *"even after `/secu login`
it is still protected (+)"*. He was reporting the `+` as the evidence. It was not evidence of
anything: the click was refused for the reason in ticket 01, and the `+` would have stayed there
either way.

So the mark meant to inform is read as a status, and a pilot has no way to tell "you need rights
for this" from "you have been refused".

## Done when

- Whatever is decided, a pilot can tell the two apart. Options, cheapest first:
  - leave the `+` and make the refusal message say what is needed and what he has (it currently
    says only `radio.auth_required`);
  - drop the `+` and carry the information in the refusal alone;
  - rebuild the menu on elevation so the mark follows the right — the most faithful, and the most
    expensive: a rebuild per elevation, per group, for a mark.
- Whichever way, `doc/` says what the `+` means, because it is the first thing a pilot sees.

## Resolution

The cheapest option: the `+` stays, and the refusal says what it cannot — *"This '+' command needs
level 10; your group acts at level 0 (its lowest pilot). A pilot with enough level can type /secu
elevate."* It was also shown with `trigger.action.outText`, to **every player on the server**; it now
goes to the group that clicked. `veafSecurity.md` (+ EN) says the `+` means "asks for a level", not
"you do not have it". Two tests in `test_veafRadio.lua`.
