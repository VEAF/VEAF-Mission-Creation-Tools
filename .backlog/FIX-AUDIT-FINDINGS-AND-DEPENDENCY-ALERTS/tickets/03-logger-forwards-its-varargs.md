# 03 — the logger forwards its varargs

Status: ✅ done — 2026-09-28

Source: `davidp57/security-audits#88`, **re-sized** after measurement on 2026-09-28.

## What the finding said, and what was measured

The five `veaf.Logger` methods (`src/scripts/veaf/veaf.lua:4399-4435`) call
`veaf.Logger.formatText(text, arg)`: they read the implicit `arg` table of a Lua 5.0 vararg
function instead of forwarding `...`, and `formatText` then reads its first vararg as that table.
The finding claimed DCS runs LuaJIT, where `arg` does not exist, so that 727 call sites log raw
`%s` with none of their values.

**That consequence does not happen.** The six production `dcs.log` files on `dcs.veaf.org` all
carry `VEAF|I|…: veaf.Development=[false]` — the formatted output of
`info("veaf.Development=%s", …)` at `veaf.lua:5502` — and none of their 4 000+ VEAF lines holds a
raw placeholder. The mission scripting environment has `arg` (PUC-Rio 5.1 with
`LUA_COMPAT_VARARG`, as the CI runs it). See the PRD for the lines.

What stays true: the logger that every module uses depends on a compatibility feature, and the
other copy of the same logger, `dcsDataExport.lua:91-95`, was already moved off it (SECREV-2 /
VMR-079), with a comment explaining why. The two copies disagree.

## The options

**a) Align `veaf.lua` on `dcsDataExport.lua`** — the methods forward `...`, `formatText` counts
them with `select("#", ...)` and keeps its `"[nil]"` padding. About fifteen lines, no behaviour
change today, and it removes the only reason the logger would break if the scripting environment
ever dropped the compatibility flag. Cost: it touches the function behind every log line of the
framework, so the method-level test below is not optional.

**b) Do not do it.** Today's behaviour is correct and measured in production; the change buys
insurance against a runtime switch nobody has announced. Record the measurement in
`known-limitations.yaml` (`kind: dcs`: *the mission environment exposes `arg` in vararg
functions*) so the next audit does not re-file it.

**Recommendation: a)**, low priority within the lot. The two copies of one logger disagreeing is
the kind of thing that re-grows findings, and the test it brings is the one nobody has: every
existing test of `formatText` calls it directly or with strings free of `%`.

## Test (option a)

At the **method** level, not `formatText`: `log:info("a=%s b=%s", 1, nil)` produces `a=1 b=[nil]`,
for each of the five levels. This cannot fail before the fix under the CI's PUC-Rio 5.1 — the
premise that would make it fail is the one the measurement refuted — so say so in the test's
comment rather than claiming a regression test.
