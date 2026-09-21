# 04 — Check 13 says it no longer discriminates, and points here

Status: ✅ done

Check 13 of `verify-mission-c` was written when the spotter network shipped, and
`FIX-SKYNET-HELPER-AND-VENDORING` made it indiscriminate three days later by turning the last line of
defence on: the only red units able to spot in that mission are two trucks with 3 km of sight, sitting
8.9 km from a battery whose own radius is now 10–15 km.

It is **not deleted**. It still carries readings worth taking in a session — the F10 menu, the
coalition scoping, the game-master case — and deleting the question would lose them. What changes is
that it no longer claims to answer *"does the word travel?"*, and says where that is answered.

## Definition of done

- [x] The check states plainly why it cannot discriminate, with the four measured figures.
- [x] It points at `demo-spotter-network`.
- [x] What it can still answer is kept and marked as such.
