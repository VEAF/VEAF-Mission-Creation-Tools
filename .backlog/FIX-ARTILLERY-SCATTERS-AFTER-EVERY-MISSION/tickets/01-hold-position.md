# 01 — la batterie reste en place

Status: ✅ done

Partie de [FIX-ARTILLERY-SCATTERS-AFTER-EVERY-MISSION](../PRD.md).

Passer `counterbattaryRadius` de 500 à **0** dans la tâche `FireAtPoint`, derrière une constante nommée qui
porte la raison. Puis couvrir la tâche remise à DCS : les deux axes, le nombre d'obus, le rayon de zone et
`expendQtyEnabled` — rien de tout ça n'était sous test.

Fini quand remettre 500 fait tomber un test.
