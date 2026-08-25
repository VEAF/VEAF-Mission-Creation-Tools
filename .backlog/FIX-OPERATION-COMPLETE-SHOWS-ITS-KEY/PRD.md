# FIX-OPERATION-COMPLETE-SHOWS-ITS-KEY — a completed operation prints its translation key

Status: ✅ done

Found in game on 2026-08-25, on the demo mission: the briefing of a finished operation ended with the
literal text `combatzone.operation_complete`.

## The defect

`VeafCombatOperation:getInformation()` builds the operation's briefing. When the operation is no longer
active — that is, when it is **complete**, the moment a player is most likely to read it — it appends
(`veafCombatZone.lua:2041`):

```lua
message = message .. string.format(veafCombatZone.EventMessages.CombatOperationComplete, self:getFriendlyName())
```

`veafCombatZone.EventMessages.CombatOperationComplete` is not a message. It is the **key**
`"combatzone.operation_complete"`, which `veaf.t` is supposed to resolve. So two things go wrong on one
line:

1. the key is printed to the player instead of the sentence;
2. the operation's name is silently dropped — the key contains no `%s`, so `string.format` returns it
   unchanged and discards the argument.

The same constant is used correctly forty lines further down (`:2143`):
`trigger.action.outText(veaf.t(veafCombatZone.EventMessages.CombatOperationComplete, self.friendlyName), 10)`.
Two call sites, one right and one wrong, which is why nobody noticed: the *event* message was fine, only
the *briefing* was broken.

## The family, enumerated

Two sweeps, because the same symptom has two possible causes.

**Keys used without `veaf.t`.** Every constant in `src/scripts/veaf` whose value is a translation key, and
every use of one: three hits, and **two are legitimate guards** (`if veafCombatZone.EventMessages.X then`).
Only `:2041` renders one.

**Keys asked for but never defined** — the same raw key on screen, arriving from the other direction.
358 keys defined, 282 asked for literally, **none missing**.

So the family is exactly one line. Established rather than assumed.

## Definition of done

- [x] A completed operation's briefing shows the sentence, not the key
- [x] It names the operation, which the broken line dropped
- [x] A test that fails on a raw key in that message — five, including one on the *active* branch so the
      fix cannot become "always print the completion sentence"
- [x] The sweeps above recorded here, so the next reader does not redo them

### Mutations

| Mutation | Result |
|---|---|
| the completion sentence in both branches | 7 tests fail |
| back to `string.format` (the defect) | 2 tests fail |
| the operation's name no longer passed | 1 test fails |

### A note on the first sweep

It reported **78** keys asked for but never defined, which would have meant every VEAF radio menu showing
raw keys. It was wrong: the pattern allowed two dot-separated segments and the menu keys have three
(`menu.combatzone.get_info`). Corrected, the answer is 358 defined, 282 asked, none missing. Worth
recording because the wrong number was alarming and would have sent someone hunting a fault that is not
there.
