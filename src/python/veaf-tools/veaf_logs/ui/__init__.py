"""Interface graphique de veaf-logs (Qt / PySide6).

* `main_window` assemble la fenetre : onglets, profils, suivi ;
* `model`       expose l'index a la vue, sans jamais garder de texte ;
* `delegate`    dessine la colonne Message et surligne les correspondances ;
* `panels`      le panneau lateral a trois etats et la barre de recherche ;
* `indexing`    etale l'indexation d'un gros journal sur plusieurs tranches.
"""
