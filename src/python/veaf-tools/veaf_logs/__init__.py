"""veaf-logs : lecture et suivi des journaux de DCS World.

L'organisation suit le chemin d'une ligne de journal :

* `buffer`   lit les octets du fichier, sans le charger ni le verrouiller ;
* `store`    les decoupe en entrees et les classe, dans un index compact ;
* `rules`    porte le catalogue (`rules.json`) qui dit comment classer ;
* `parser`   decrit la forme d'une entree et les motifs partages ;
* `filters`  choisit les entrees a montrer : recherche, tri-etat, contexte ;
* `tailer`   ouvre un journal et repere sa rotation ;
* `profiles` et `session` conservent les reglages entre deux lancements ;
* `ui`       affiche tout cela.

Documentation d'usage : `doc/mission-maker/LOGS.md`.
"""
