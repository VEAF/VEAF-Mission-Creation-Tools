# VEAF Mission Creation Tools — v6.3.0

**Release Date:** 2026-05-31

## Highlights

- **Fix: crash lors de la conversion v5→v6** — `convert-v5` ne plante plus sur les missions dont les tables Lua contiennent des clés mixtes (entiers et chaînes)
- **veaf-tools s'auto-pause après un double-clic** — la fenêtre ne se ferme plus avant que vous ayez pu lire la sortie
- **Defaults intelligents** — `veaf-tools build` ne copie plus les fichiers de config inutilisés quand leur module est désactivé dans `mission.yaml`
- **veaf.initialize() plus robuste** — message d'erreur clair si `veafCommands.lua` est absent (scripts VEAF trop anciens)

---

## For Mission Makers

### Bug fix — crash de convert-v5 sur certaines missions

`veaf-tools convert-v5` pouvait planter avec `TypeError: '<' not supported between instances of 'int' and 'str'` lors de la conversion de missions dont le `missionConfig.lua` générait des tables Lua avec des clés à la fois entières et chaînes. Ce bug est corrigé.

### veaf-tools build — auto-pause après un double-clic

Quand vous lancez `veaf-tools.exe` en double-cliquant dessus (et non depuis un terminal), l'outil **s'arrête automatiquement en fin d'exécution** pour vous laisser le temps de lire la sortie avant que la fenêtre se ferme. Le comportement s'adapte à la façon dont vous avez lancé l'outil :

- **Double-clic** : pause et attend un appui sur une touche
- **Terminal / CI** : se termine immédiatement comme avant

Les flags `--pause` et `--no-pause` restent prioritaires et surchargent cette détection automatique.

### Gestion intelligente des fichiers de config par défaut

`veaf-tools build` ne copie plus les fichiers de template par défaut (ex. `aircraft-templates.yaml`, `waypoints.yaml`) dans votre dossier mission quand l'étape de pipeline ou le module Lua correspondant est **désactivé** dans `mission.yaml`. Si l'un de ces fichiers existe déjà mais que son module est désactivé, vous recevez maintenant un avertissement explicite.

### convert-v5 — config annotée dans le rapport

Le `missionConfig.lua` annoté (qui montre ce que chaque ligne a été migrée vers) est maintenant intégré **directement dans le rapport de conversion** (`convert-v5-report.md`) sous forme de bloc de code Lua, au lieu d'être écrit dans un fichier séparé dans `backup_v5/`. Le rapport est autonome et plus facile à consulter.

---

## For Mission Script Developers

### veaf.initialize() — nil-check pour veafCommands

Si votre mission utilise un `veaf-scripts.lua` antérieur à l'introduction de `veafCommands.lua`, `veaf.initialize()` affiche maintenant un message d'erreur clair au lieu d'échouer silencieusement. Mettez à jour votre `veaf-scripts.lua` pour corriger ce problème.

---

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes.
