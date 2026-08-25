# 01 — retrouver un groupe par le nom qu'on lui a donné

Status: ✅ done

Partie de [FEAT-GROUPNAME-PARTIAL-MATCH](../PRD.md).

Écrire `veaf.findGroupByPartialName`, à côté de `veaf.getNameForSpawnedGroup` — les deux fonctions sont des
contraires. Nom exact d'abord, sinon les groupes dont le nom contient la chaîne, sans tenir compte de la casse
et dédoublonnés par nom. Un seul candidat gagne ; plusieurs sont rendus à l'appelant pour qu'il les nomme.

Fini quand `groupname arty-1` désigne `[b]-arty-1#7`, et quand `arty-1` en présence de `arty-10` refuse au
lieu de choisir.
