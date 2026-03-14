TUI/GUI/WebUI
 - au lancement si pas d'option 
 - stocker les options décidées dans le TUI par l'utilisateur pour lui reproposer la prochaine fois

Installer les outils + scripts dans leur propre répertoire (centralisé)

veaf-tools check la version et proposer de lancer l'updater

build-ands-publish insère dans l'exe des données calculées comme la liste des modules

configuration:
- initialiser des paramètres veaf.config pour chaque module au chargement
- pour chaque module, on ajoute une option "disable" dans les paramètres qui est à false
- permettre de les changer dans missionconfig si il existe
- initialiser tous les modules après le chargement de missionconfig
- générer une template de missionconfig
- choix des modules à activer avec quelques options bateau dans le yaml de la mission

logger:
- permettre le choix des modules qui vont logger (option de veaf-tools.exe)

parser la table DCSUnits et faire une petite doc dynamique avant le publish

Outils python
https://docs.pydantic.dev/latest/
ruff
mypy
poetry

