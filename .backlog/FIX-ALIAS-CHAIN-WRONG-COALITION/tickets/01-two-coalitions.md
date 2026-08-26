# 01 — deux coalitions dans la chaîne

Status: ✅ done

Partie de [FIX-ALIAS-CHAIN-WRONG-COALITION](../PRD.md).

Faire descendre `requesterCoalition` à côté de `coalition` dans `veafShortcuts.executeCommand`,
`ExecuteAlias` et `VeafAlias:execute`, y compris dans la boucle du lot et la table d'arguments du report.
Seul l'appel à `veafGroundAI` la consomme ; le reste garde la coalition du spawn. À défaut, on retombe sur
celle de la chaîne.

Fini quand annuler le correctif fait tomber un test, et quand le retirer du point d'entrée, du lot ou du
report en fait tomber un aussi — c'est là que les trois manques étaient.
