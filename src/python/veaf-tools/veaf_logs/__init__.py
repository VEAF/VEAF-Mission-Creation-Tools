"""veaf-logs : le coeur sans fenetre de la lecture des journaux de DCS World.

Le `veaf-logs.exe` livre est le viewer Go de `src/go/veaf-logs/` (ADR 0023).
Ce paquet reste pour le bot de support, qui l'importe, et comme reference des
tests de parite du Go, dont il ecrit les goldens.

L'organisation suit le chemin d'une ligne de journal :

* `buffer`   lit les octets du fichier, sans le charger ni le verrouiller ;
* `store`    les decoupe en entrees et les classe, dans un index compact ;
* `rules`    porte le catalogue (`rules.json`) qui dit comment classer ;
* `parser`   decrit la forme d'une entree et les motifs partages ;
* `filters`  choisit les entrees a montrer : recherche, tri-etat, contexte ;
* `profiles` porte les profils de filtres ;
* `analysis` et `report` font *Expliquer* et le rapport `/bug`.

Documentation d'usage : `doc/mission-maker/LOGS.md`.
"""
