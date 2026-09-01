# 01 — Guard, or prove unreachable

Status: ✅ done

Type: fix · Files: see the table in the PRD

## How to work it

Take them one at a time, in the PRD's order — it is roughly severity order. For each:

1. Read the call site. Some of these may be unreachable because the caller already guarantees the
   object exists (`veafAirbases.lua:105` is the likeliest candidate).
2. If reachable: guard it, report the failure at `warning` naming the object, and decide what the
   function does next rather than letting it fall through.
3. If not reachable: **leave a comment saying why**. An unexplained absence of a guard is what
   produced this lot; the next sweep must not have to re-derive your reasoning.

Follow the shape PR #872 used in `veafCombatMission.lua` — same warning, same test through the DCS
mocks — so they all read alike.

## Two that are not plain guards

**`veaf.lua:2201-2206`** — `getAvgGroupPos` accepts a name *or* a group. When given a string whose
group does not exist, `group` keeps the string and `group:getSize()` is called on it. A guard would
hide it; the fallback itself is wrong. Decide what the function returns when the group is gone —
`nil` is defensible, and callers must be checked for it.

**`veafSanctuary.lua:767` and `veafMove.lua:856/864`** — the guard exists and tests the wrong
variable. Fix the condition, and remove the `---@diagnostic disable-next-line: need-check-nil` that
was silencing the warning instead of leaving it disabled over corrected code.

## Definition of done

- [x] Every location in the PRD table is guarded or documented as unreachable
- [x] The four silenced `need-check-nil` are resolved or re-justified
- [x] `getAvgGroupPos` no longer calls a method on a string
- [x] Tests through the mocks wherever the path is reachable
- [x] The PR states, per location, what was done and why
- [x] `poetry run test-lua` green, `stylua --check` clean
