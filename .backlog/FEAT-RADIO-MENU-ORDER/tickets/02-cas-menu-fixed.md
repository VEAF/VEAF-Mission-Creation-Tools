# 02 — The CAS menu stays, its entries stay

Status: ⬜ ready

## Done when

- The MISSION CAS menu is built once and never deleted; with no CAS mission it shows a "no CAS mission: place `-cas` on the F10 map" line and its help (PRD D3, test).
- Its mission entries are fixed: started, ended, smoke and flare requested — no entry is deleted or recreated, each answers when it cannot act (D4, tests counting the builder's added/removed entries).
- What was measured about the English-literal `delCommand` titles is written in the PR.
