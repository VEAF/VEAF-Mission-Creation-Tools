# 02 — The F10 report adopts it, because it changes nothing

Status: ✅ done
Type: feat

The PRD asks for **one** caller to adopt the predicate, and warns that `completionCheck` is *"the
visible one and therefore the riskiest"* — adopting it changes when zones complete, in every existing
mission.

So the first adopter is the **F10 report**. It adds information and removes none: a player asking what
is left in a zone is told which of its groups can no longer fight. No mission behaviour changes, which
is exactly what a first adopter should be able to promise.

## Definition of done

- [x] The zone report names the groups that are no longer combat-effective
- [x] A zone whose groups are all effective reads exactly as it does today
- [x] i18n in both languages
- [x] Lua tests over the report text
