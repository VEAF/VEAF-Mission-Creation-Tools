# 08 — Four rough edges the first real run showed

Status: ⬜ ready

Type: fix

## Where these come from

David ran `/ask`, `/suggest` and `/bug` for real on 2026-09-07, against the live Discord, the live
Worker and the live tracker. Everything worked. These four are what he saw while it did — none is a
failure, all four are visible to whoever uses the bot next.

## 1. A component nobody can filter on

Issue #929 was filed as component **`Other`**, while the code it located was
`src/scripts/community/AIEN.lua` — Lua that runs in a mission, so `Lua runtime scripts
(in-mission)`. Cause: `COMPONENT_RULES` in `bugreport.py` knows `src/scripts/veaf/` and nothing else
under `src/scripts/`. Everything community-shipped falls into the catch-all.

One line. But the component drives a label, so today those reports are unfilterable.

## 2. English sentences in a French issue

In the body of #929, among French headings:

> *« 1202 of 10455 records kept by the Diagnostic profile; 38 of them match no catalogue entry. »*

and, in the attachment manifest:

> *« non publié ici : 1840576 bytes, past the 24000 an issue can carry — see the excerpt above »*

Both are written in `attachments.py`, outside the translation catalogue. Same family as the modal
labels of ticket 01: the service translates what it *says* through `texts.py` and hard-codes
everything else.

## 3. Two counters that contradict each other on sight

The same section says **1202 records kept**, then `[veaf-logs] 48 entrées sur 10455 indexées (1202
retenues, 1154 omises par la limite de taille)`. They measure different things — entries rendered in
the excerpt, records kept by the profile — and side by side they read as an inconsistency. Name
them, or show one.

## 4. The idempotency marker is visible in the Discord preview

Every draft opens with:

```
<!-- veaf-support-bot:report=ad7bd4fe8e96c2232cc9da0f52e32b89 -->
```

Invisible on GitHub, where it is an HTML comment and where the recovery search greps for it. Discord
renders it as text, so the preview starts with a line nobody can read. The marker must stay in the
**issue**; it has no reason to be in the preview.

## Definition of done

- [ ] `src/scripts/` maps to the Lua component, with its label, and the rule covers what is under it
      rather than one directory
- [ ] The log digest and the attachment manifest speak the reporter's language
- [ ] The two counters are named for what they count, or reduced to one
- [ ] The preview does not show the marker; the filed issue still carries it, and the recovery
      search still finds it
- [ ] Unit tests per point, the marker one asserting both halves
- [ ] Quality gate clean
