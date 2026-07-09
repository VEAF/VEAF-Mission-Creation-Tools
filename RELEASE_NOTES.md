# VEAF Mission Creation Tools — 6.9.0

Version centrée sur les **planchettes radio (kneeboards)**. Deux nouveautés
d'auteur, valables sur **tous les appareils** : vous pouvez désormais **mettre en
évidence les canaux importants** (priorité) et **regrouper vos canaux par couleur**
directement sur la planchette. Et chaque type d'appareil reçoit sa **propre
planchette** dédiée. L'**AJS-37 Viggen** en est la vitrine : ses radios enfin
pilotées de bout en bout par votre plan de fréquences. Encore nourrie par les
retours de **Tripack**.

## 🖍️ Priorité des canaux — mettez en avant l'essentiel

Ajoutez `priority: <n>` à un canal de votre plan : il est **surligné en orange**
sur la planchette, avec un marqueur `Pn` — un coup de stabilo pour repérer d'un
coup d'œil vos fréquences clés (Guard, tanker, AWACS…). Valable sur tous les
appareils.

Sur l'**AJS-37**, la priorité a un **effet supplémentaire** : les priorités 1 à 4
alimentent automatiquement les raccourcis matériels **FR22 Special 1/2/3** et
**FR24 H** — un même attribut sert donc à la fois à baliser la planchette (partout)
et à câbler les boutons du Viggen (voir la vitrine plus bas).

## 🎨 Couleur des canaux — regroupez visuellement

`color: green` (ou `#RRGGBBAA`) colorise la case du numéro de canal, pour
regrouper d'un coup d'œil des familles de canaux (aérodromes, flights, tankers…).
Le texte s'adapte automatiquement pour rester lisible.

## 📄 Une planchette par type d'appareil

Chaque modèle qui reçoit des presets a désormais **sa propre planchette**, rangée
dans le dossier DCS du type (`KNEEBOARD/<type>/IMAGES/`) — fini la page générique
partagée. Présentation épurée : entêtes de radio en **gris** (plus de codage
rouge/vert/orange).

📖 Doc : [Pipeline Reference — priorité & couleur des canaux](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/PIPELINE_REFERENCE.md)

## ✈️ Vitrine : l'AJS-37 Viggen

L'avion le plus retors côté radio sert d'exemple à tout ça :

- Les **priorités 1 à 4** remplissent automatiquement les raccourcis **FR22
  Special 1/2/3 et FR24 H** — vous ne gérez que votre plan de fréquences.
- Ses 40 canaux FR22 (Groups **100-139**) sont enfin projetés depuis le plan, avec
  la convention pilote « canal N = Group 10N ».
- Sa planchette affiche les **vrais libellés cockpit** (100-139 puis
  Sp1/Sp2/Sp3/E/F/G/H) et tient sur **deux colonnes** pour rester lisible.

## ⚠️ À vérifier (mission makers)

- Les formats de presets existants restent **entièrement supportés**.
- **Planchettes déplacées** : plus de pages dans `KNEEBOARD/IMAGES/presets-*.png` ;
  désormais une page par type dans `KNEEBOARD/<type>/IMAGES/`. À savoir si vous
  référenciez les anciens chemins.
- **AJS-37 via le plan `channel_lists`** : la carte de canaux packée change (canal
  100 = 20ᵉ de primary_2, raccourcis remplis par `priority`). La conversion
  `convert-v5`, elle, reste fidèle (`presets.v5.yaml`).
- Aspect planchette : entêtes de radio en gris.

## 🙏 Remerciements

Merci à **Tripack**, dont le travail sur l'AJS-37 et les retours de missions
réelles sont à l'origine de cette version.
