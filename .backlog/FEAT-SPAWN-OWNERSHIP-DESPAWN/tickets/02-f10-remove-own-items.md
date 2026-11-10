# 02 — F10 menu: list and remove one's own items

Status: ⬜ ready

## Done when

- Under the group's F10 menu, the owner's items are listed, each named by what he typed and its time, with one entry that removes them all (PRD Q3); a partly destroyed group is removed whole (Q8).
- In a multi-seat aircraft, the items of every occupant are shown, each under his name (Q4).
- The removal is open to its owner and to nobody else through this menu; `-destroy` stays for trusted members (Q6, Q7). Nothing is removed when the pilot leaves (Q5).
- The F10 menu id recycling trap is respected (`docs/agents/dcs-runtime-traps.md`); luaunit tests.
