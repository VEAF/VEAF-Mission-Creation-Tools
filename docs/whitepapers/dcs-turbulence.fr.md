# Ce que DCS fait du réglage de turbulence

Mesure en jeu du 2026-10-31, DCS 2.9 (même installation que [le modèle du vent](dcs-wind-model.fr.md)).
Question posée : un réglage `mission.weather.groundTurbulence` donné produit quelles rafales, à quelle hauteur, et quel réglage écrire pour reproduire l'écart de rafale d'un METAR sans rendre les hélicos impilotables.

## 1. En bref

- **L'unité** : `groundTurbulence` est en dixièmes de m/s. L'éditeur écrit `valeur affichée × 10` (`MissionEditor/modules/me_weather.lua`, `createTurbulencePanel`) et borne la saisie à **0–6 m/s** (`me_weather_panel.dlg`). Dans la suite, S désigne le réglage en m/s : `groundTurbulence = 10 × S`.
- **Tout est proportionnel à S**, à trois décimales près, de 1 à 7 m/s : la turbulence est un bruit fixe multiplié par le réglage.
- **Le bruit est le même à chaque lancement** : deux missions qui ne diffèrent que par S rejouent exactement la même suite de rafales, mise à l'échelle.
- **Le vent ajoute un plancher, il ne s'additionne pas** : la turbulence produite est la plus forte des deux, celle du réglage ou celle que DCS tire du vent.
- **Correspondance avec le METAR** : à 10 m sol, un réglage S donne un écart de rafale « à la METAR » de 0,62 × S. Pour reproduire un écart G (rafale − vent moyen), il faut **S = G / 0,62 ≈ 1,6 × G**.
- **Ordre de grandeur pour un hélico** : à 10 m sol, les pointes horizontales atteignent 0,9 à 1,1 × S, les verticales 0,5 à 1,0 × S ; vers 1000 ft, les pointes verticales montent à 1,1 × S.

## 2. Méthode

Une mission vide sur Syria, la même que pour le modèle du vent, déclinée en dix réglages : sans vent, S = 0, 1, 2, 3, 5 et 7 m/s ; avec 10 m/s de vent au sol, S = 0, 2 et 6 ; avec 5 m/s de vent au sol, S = 3 sur 20 minutes.
DCS hébergeait une partie multijoueur locale ; un hook GUI temporaire ([veaf-turb-loader.lua](dcs-turbulence/veaf-turb-loader.lua)) chargeait chaque mission à neuf, sans mesure empilée sur un même état.

Dans chaque mission, un échantillonneur lit toutes les 0,05 s `atmosphere.getWindWithTurbulence(p)` et `atmosphere.getWind(p)` en points fixes au-dessus d'Abu al-Duhur (terrain plat, 250 m) : 10 m, 100 ft, 500 ft, 1000 ft, 1500 ft et 1000 m sol, plus deux points au-dessus de la mer (10 m et 1000 ft).
La turbulence est l'écart entre les deux.
Chaque relevé dure 5 minutes (20 pour le relevé long), soit 6 000 à 24 000 lectures par point.
Il prend aussi deux coupes spatiales de 10 km (un point tous les 5 m) à 60 s d'écart, pour savoir si le champ est figé, se déplace ou se renouvelle sur place.

La météo réellement chargée est relue dans `env.mission.weather` à chaque relevé : c'est elle qui fait foi.

## 3. Résultats

### 3.1 Par m/s de réglage, sans vent

Coefficients à multiplier par S. Ils sont identiques à 0,001 près pour S = 1, 3, 5 et 7.
« Pointe » est le maximum sur 5 minutes ; « durée » est le temps au bout duquel une rafale est oubliée (autocorrélation sous 1/e).

| Hauteur sol | Horizontal : moyenne quadratique | Horizontal : p95 | Horizontal : pointe | Vertical : moyenne quadratique | Vertical : pointe | Durée d'une rafale |
|---|---|---|---|---|---|---|
| 10 m | 0,39 | 0,69 | 0,90 | 0,24 | 0,53 | 11 s |
| 100 ft | 0,31 | 0,51 | 0,66 | 0,28 | 0,68 | 14 s |
| 500 ft | 0,36 | 0,68 | 0,80 | 0,42 | 0,85 | 38 s |
| 1000 ft | 0,41 | 0,73 | 0,82 | 0,47 | 1,12 | 38 s |
| 1500 ft | 0,24 | 0,41 | 0,46 | 0,45 | 0,84 | 49 s |
| 1000 m | 0,17 | 0,23 | 0,23 | 0,47 | 0,50 | 69 s |

Au-dessus de la mer, les mêmes ordres de grandeur : à 10 m, 0,30 de moyenne quadratique horizontale et 0,82 de pointe.

Sur le relevé long (20 minutes, S = 3, vent de 5 m/s), les pointes à 10 m montent à 1,14 × S à l'horizontale et 0,97 × S à la verticale : les pointes sur 5 minutes sous-estiment ce qu'un vol plus long rencontre.

### 3.2 Le champ dans l'espace et le temps

- À 10 m sol, la longueur de corrélation est de **20 m** et le champ se renouvelle sur place : 60 s plus tard, la coupe ne ressemble plus à la première (corrélation 0,39), sans déplacement d'ensemble.
- À 1000 ft, la longueur de corrélation est de **215 m** et le champ change peu : corrélation 0,80 à 60 s d'écart, décalé de 20 m.
- Conséquence pour un hélico : en stationnaire près du sol, les rafales arrivent toutes les dix secondes environ ; en translation à 40 kt, il traverse une cellule de 20 m en une seconde, donc il ressent des secousses bien plus rapides qu'en stationnaire.

### 3.3 Le vent ajoute un plancher

Avec 10 m/s de vent au sol et S = 0, la turbulence n'est pas nulle : à 10 m, 0,49 m/s de moyenne quadratique horizontale et 1,1 m/s de pointe, soit l'équivalent d'un réglage de **1,2 m/s** environ.
C'est le plancher que [le modèle du vent](dcs-wind-model.fr.md) avait vu (section 3.4).
Sa répartition en hauteur diffère de celle du réglage : faible entre 500 et 1500 ft, forte à 1000 m sol (2,5 m/s de moyenne quadratique verticale), là où le profil du vent change de pente.

Avec du vent et un réglage, DCS ne fait pas la somme : à chaque hauteur, la turbulence est **la plus forte des deux**.
Avec 10 m/s de vent, S = 2 et S = 6 donnent à 10 m exactement les mêmes chiffres que sans vent ; à 1000 m, S = 2 donne le plancher du vent, S = 6 le dépasse à peine.

Conséquences :

- avec du vent, un plafond de turbulence sous le plancher ne change rien ;
- le plancher n'a été mesuré qu'avec 10 m/s de vent au sol ; qu'il soit proportionnel au vent est une hypothèse, non mesurée ici.

### 3.4 Correspondance avec le METAR

Un METAR donne la rafale comme la pointe de la vitesse moyennée sur 3 s, sur 10 minutes.
Sur le relevé long, découpé en onze fenêtres de 10 minutes, l'écart « pointe 3 s − vitesse moyenne » à 10 m vaut **0,55 à 0,68 × S, 0,62 × S en moyenne**.
Pour reproduire un écart de rafale G du METAR :

```
S = G / 0,62          groundTurbulence = 10 × min(S, plafond)
```

En nœuds : `groundTurbulence ≈ 8,3 × (rafale − vent moyen)`, avant plafond.
La fonction et sa table sont dans [gust_to_turbulence.py](dcs-turbulence/gust_to_turbulence.py) :

| Écart METAR | Réglage S sans plafond | `groundTurbulence` |
|---|---|---|
| 2 kt (1,0 m/s) | 1,7 m/s | 17 |
| 4 kt (2,1 m/s) | 3,3 m/s | 33 |
| 6 kt (3,1 m/s) | 5,0 m/s | 50 |
| 8 kt (4,1 m/s) | 6,6 m/s | 66 |
| 13 kt (6,7 m/s) | 10,8 m/s | 108 |

Ce que fait Real Weather aujourd'hui : il met la **pointe** de rafale en réglage (S = rafale, en m/s), pas l'écart.
Pour `08024G37KT` à Marteau du Golan, il voulait S = 19 m/s, borné à 7 : DCS produisait alors des pointes de 6,3 m/s à l'horizontale et 3,7 m/s à la verticale à 10 m, et 7,8 m/s à la verticale à 1000 ft.
Avec la bonne correspondance, l'écart de ce METAR (13 kt) demanderait S = 10,8 m/s, au-delà de ce que l'éditeur permet : sur un METAR rafaleux, c'est le plafond qui décide.

## 4. Plafond recommandé

**Reco provisoire : S = 3 m/s (`groundTurbulence = 30`)**, à confirmer par le test aux commandes (section 5).

- Avec S = 3, les pointes à 10 m sont de 2,7 à 3,4 m/s (5 à 7 kt) à l'horizontale et de 1,6 à 2,9 m/s à la verticale ; vers 1000 ft, 3,4 m/s à la verticale.
- C'est l'écart de rafale qu'annonce un METAR de 4 kt d'écart : en dessous, la turbulence suit le METAR, au-dessus, elle est écrêtée.
- Le plafond provisoire de 2 m/s appliqué à l'écart brut correspond à un réglage de 2 m/s, soit une rafale de 1,2 m/s (2,4 kt) : trop timide pour que les rafales du METAR se sentent, mais sûr.
- Un plafond sous 1,2 m/s ne sert à rien par 20 kt de vent : le plancher du vent l'emporte (section 3.3).

## 5. Test aux commandes

Cinq missions, sur la même rangée de terrain plat à 1,5 km à l'ouest d'Abu al-Duhur, vent nul, huit hélicos au sol moteurs tournants (UH-1H, Mi-8, Mi-24P, Ka-50 III, Gazelle M, OH-58D, AH-64D, CH-47F) : `veaf-turb-helico-0ms.miz` (témoin), `-2ms`, `-3ms`, `-4ms`, `-5ms`.
Elles sont écrites par [make_helico_missions.py](dcs-turbulence/make_helico_missions.py).
La consigne pas à pas est donnée à David dans la session de mesure ; elle remplace celle de la tâche T434.

Le critère : la plus forte turbulence où le stationnaire à 10 ft et la pose restent faisables sans lutter devient le plafond.

## 6. Limites

- **Un seul bruit** : DCS rejoue la même suite à chaque lancement ; les pointes mesurées sont celles de cette suite, pas une statistique sur plusieurs tirages.
- **Le plancher du vent** n'a été mesuré qu'à 10 m/s de vent au sol.
- **Le coefficient 0,62** vient d'un seul relevé de 20 minutes, en un point ; il varie de 0,55 à 0,68 selon la fenêtre.
- **Le ressenti d'un aéronef** passe par le même vent, mais le modèle de vol filtre peut-être autrement : le test aux commandes tranche.
- **Mesuré en multijoueur hébergé**, sur le moteur de mission ; le modèle du vent avait été mesuré en solo, avec les mêmes fonctions.

## 7. Fichiers

Dans [dcs-turbulence/](dcs-turbulence/) :

| Fichier | Rôle |
|---|---|
| `make_turb_missions.py` | écrit les dix missions de mesure à partir de `veaf-survey-Syria.miz` |
| `veaf-turb-loader.lua` | hook GUI temporaire : charge la mission demandée quand DCS héberge une partie |
| `run_all.py` | enchaîne chargement et mesure, mission par mission |
| `measure_turbulence.py` | échantillonneur et coupes spatiales, écrit `data/<nom>.json` |
| `analyse_turbulence.py` | les tableaux de la section 3 |
| `gust_to_turbulence.py` | écart METAR → `groundTurbulence`, avec plafond |
| `make_helico_missions.py` | les missions du test aux commandes |
| `data/*.json` | les relevés bruts |
