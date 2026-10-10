# 10 — A campaign mission flies with the server's security

Status: ✅ done
Type: fix

## Found

The *Kolkhida* template, written by Claude, carried `security: { disabled: true }`, the setting of a test mission; mission 1 was flown by the squadron with every protected command open.
David, 2026-10-09: "il faut la sécurité du serveur (veaf-pilots.txt) et pas de mot de passe".

## To do

- The squadron's mission: no `security.disabled`, no `password_hashes` — a pilot listed in the server's `veaf-pilots.txt` passes by his level, through the server hook.
- `campaign next` writes the mission folder that way and says so; a test copy turns security off afterwards, never the campaign.
- Fix the *Kolkhida* template (outside the repository).
- Tests and `CAMPAIGN.md` FR + EN.

## Done when

A mission folder created by `campaign next` has no `security.disabled` and no password, whatever the template held.
