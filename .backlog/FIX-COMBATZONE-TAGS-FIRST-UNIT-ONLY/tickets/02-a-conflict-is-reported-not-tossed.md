# 02 — Two units disagreeing about a tag is reported, not tossed

Status: ✅ done
Type: fix

Depends on [01](01-read-the-tags-off-every-name.md).

## The problem this creates

Reading every name introduces a case that cannot happen today: two units of one group carrying
`#alarm=0` and `#alarm=2`, or a group name saying `#spawnchance=50` while a unit says
`#spawnchance=100`. One of them has to lose.

## The rule

The first source in the fixed order wins — group name, then unit names alphabetically — and every later
source carrying a **different** value for the same tag is ignored with a `warn` naming both values and
where they came from. A later source repeating the *same* value is silent: tagging every truck of a
convoy identically is the ordinary way of doing it and must not produce a log line per truck.

This follows the precedent set by `FIX-COMBATZONE-CONVOY-ALARM`, whose `#alarm=7` fallback was made to
warn for the same reason Sourcery gave then: a fallback nobody is told about makes a mistake look like a
choice.

The existing warning for an unreadable `#alarm` tag (`#alarm=`, `#alarm=x`, `#alarm=-1`) moves to the
collection step and keeps its meaning — it fires when **no** source produced a state and at least one
carried the `#alarm` text.

## Definition of done

- [x] Conflicting values produce one `warn` and the first source's value
- [x] Repeated identical values produce no warning
- [x] The unreadable-`#alarm` warning still fires, and does not fire when another unit of the group
      states a readable one
- [x] Lua tests for all three
