# 03 — Sync CTLD rc10, the first bump the watch reported itself

Status: ✅ done

## Why it is here rather than in a lot of its own

`published-v2.0.0-rc10` shipped on **2026-09-16**, two days before this ticket, and the watch had no
way to say so — which is exactly what ticket 02 fixes. Taking the bump in the same lot is what proves
the fix: the check was run before and after, and it moved from `error` to `drifted` to `up-to-date`.

## What changed

**CTLD `2.0.0-rc9` → `2.0.0-rc10`, verbatim.** Two F10 menu defects reported in flight upstream: a
transport asking for one command on the menu and getting another (a smoke grenade instead of a troop
load), and the whole-menu rebuild that made it possible. Upstream's fix introduces an *ambient* vs
*urgent* refresh distinction, detected automatically rather than tagged at each of ~30 call sites.

Measured, not assumed:

- The download arrives with **CRLF**; the vendored copy is LF. Converted before copying — a raw copy
  shows a 37 244-line diff and would make every later comparison unreadable. Real diff: **419 lines**,
  283 insertions / 92 deletions, which matches two fixes and their comments.
- **The configuration catalogue is byte-identical between rc9 and rc10.** It is extracted from the
  vendored `CTLD.lua` at build time (ADR 0016), so a new setting would have to reach the scaffold;
  none did, and no mission configuration changes.
- `test_community_scripts_load.lua` — the gate `FIX-CTLD-RC9-LOAD-GATE` added after rc8 came up dead
  in flight — **loads** rc10 under the DCS mocks rather than parsing it. It passes, along with the
  47 other Lua suites.
- `test_vendored_pins_match_the_files.py` still matches: `ctld.VERSION` in the file, the `pinned`
  field and the watch tag all read rc10.

## Not claimed

The file has not been flown in DCS here. Upstream ships it inside missions people fly, and the two
defects it fixes were reported from flight — but this repository's evidence stops at "it loads and
initialises under the mocks".
