# VEAF Mission Creation Tools — 6.7.5

Version **multi-plateforme et fiabilité**. `veaf-tools` tourne désormais nativement sous **Linux et macOS** (en plus de Windows), les logs DCS identifient enfin précisément quelle version a généré une mission, et la QRA réagit correctement aux avions en slot dynamique. Aucun changement de configuration : les missions existantes n'ont rien à modifier, et le flux Windows est inchangé.

## 🐧 Linux & macOS

- **`veaf-tools` en binaire natif Linux et macOS** — l'outil n'est plus réservé à Windows. La release fournit `veaf-tools-linux-x86_64`, `veaf-tools-macos-arm64` (Apple Silicon) et `veaf-tools-macos-x86_64` (Intel), téléchargeables en un clic depuis la page de release.
- **L'updater fonctionne aussi sous Linux et macOS** — il récupère le bon binaire depuis les assets de la release, l'installe et se met à jour lui-même. *(Sur Unix, les binaires ne sont pas dans `published.zip` mais dans les assets de release — l'updater s'en charge.)*
- **`veaf-tools.exe` (Windows) en téléchargement direct** — désormais disponible aussi en asset autonome, plus seulement à l'intérieur de `published.zip`.

## 🐛 Corrections

- **La QRA réagit enfin vraiment aux avions en slot dynamique** — un avion pris en slot dynamique ne déclenchait la QRA que si `react_on_helicopters` valait `true`. Le correctif [#299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/299) (6.7.2) ne traitait qu'une partie du problème : la catégorie de l'unité était en réalité mal calculée plus en amont, dans le gestionnaire d'événements, et **tout** slot dynamique passait pour un hélicoptère. Désormais un avion slot-dyn déclenche la QRA quel que soit `react_on_helicopters`.

## 🔍 Diagnostic facilité

- **Une seule version « de build » dans les logs DCS** — au lieu d'une trentaine de numéros de version par module (qui ne correspondaient à aucune release et n'étaient pas fiables), le log affiche désormais un **stamp unique** `6.7.5+<identifiant git>` indiquant exactement quelle version de `veaf-tools` a généré la mission. En cas de souci, on sait immédiatement quel code tourne réellement.

## 🙏 Remerciements

Merci à **Tripack** pour le signalement et le repro en jeu du bug QRA, qui ont permis d'en identifier la cause racine réelle.
