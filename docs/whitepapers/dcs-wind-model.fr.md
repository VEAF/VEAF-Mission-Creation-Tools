# DCS : le vent réel n'est pas le vent réglé dans l'éditeur

*Whitepaper VEAF à l'intention des créateurs de missions DCS World et des auteurs de briefs.*
*Il décrit comment DCS calcule le vent d'une météo statique à partir des trois valeurs de l'éditeur de mission, d'après le code de `Weather.dll`, vérifié par des mesures en jeu.*
*Rédigé le 2026-10-31, DCS 2.9.31.29434, carte Syria.*

## Résumé

**Le « vent au sol » de l'éditeur n'est le vent à 10 m qu'au bord de la mer.**
DCS le multiplie par 2,14 pour en faire un vent de référence, puis le réduit près du sol, d'autant moins que le terrain est haut.
Sur un aérodrome à 250 m d'altitude, le vent à 10 m vaut 1,34 fois le réglage ; à 1000 m d'altitude, 1,87 fois.
Au-dessus du sol, le vent forcit jusqu'à environ 2,1 fois le réglage entre 300 et 600 m de hauteur, puis rejoint la valeur `at2000` en approchant 2000 m MSL.

Exemple vécu sur la mission *Marteau du Golan* : réglage 9 m/s (17 kt) au sol, 11 m/s à 2000 m.
Le brief annonçait 17 kt ; DCS simulait 24 kt à 10 m au-dessus de Rosh Pina, 27 kt à 100 ft et 36 kt à 1000 ft.

Ce qu'il faut retenir pour écrire un brief :

1. ne jamais recopier les valeurs de l'éditeur : calculer le vent réel avec l'outil fourni (section 7) ;
2. les rapports météo de VMCT (ATIS, LASTE) sont justes, puisqu'ils interrogent DCS au bon endroit (section 6) ;
3. deux directions très différentes au sol et à 2000 m créent une couche sans vent en dessous de 2000 m (section 3.3).

## 1. Ce qu'on règle

En météo statique, l'éditeur de mission propose trois vents, chacun avec une vitesse et une direction :

| Champ de l'éditeur | Clé du `.miz` | Ce que DCS en fait |
|---|---|---|
| Vent « à 10 m » (« at 33 ft ») | `weather.wind.atGround` | un vent de référence de 2,141 × la valeur, posé à 0 m MSL |
| Vent à 2000 m | `weather.wind.at2000` | la valeur telle quelle, à 2000 m MSL |
| Vent à 8000 m | `weather.wind.at8000` | la valeur telle quelle, à 8000 m MSL |

Dans le fichier `.miz`, `dir` est la direction **vers laquelle** souffle le vent : `dir = 90` est un vent d'ouest (du 270).
L'éditeur affiche en plus un champ « 500 m », calculé et non enregistré (section 4).

## 2. Le modèle

Le vent de base (sans turbulence) en un point se calcule en trois étapes.
Notations : `y` est l'altitude MSL du point, `h` sa hauteur au-dessus du sol, les vents sont des vecteurs.

### 2.1 Trois niveaux, en altitude MSL

| Niveau | Altitude | Vecteur |
|---|---|---|
| 0 | 0 m MSL | `V0 = 45^0,2 × atGround ≈ 2,1411 × atGround` |
| 1 | 2000 m MSL | `V1 = at2000` |
| 2 | 8000 m MSL | `V2 = at8000` |

Le coefficient 45^0,2 ramène un vent mesuré vers 11 m (500/45 ≈ 11,1 m) à une hauteur de référence de 500 m, par une loi de puissance d'exposant 0,2.

### 2.2 Raccord entre deux niveaux

Entre un niveau bas (`yb`, `Vb`) et un niveau haut (`yh`, `Vh`) :

```
s = (y − yh) / ((yh − yb) / 2)
w = exp(−s⁴)
V = Vb + (Vh − Vb) × w
```

`s` vaut −2 au niveau bas (w ≈ 0) et 0 au niveau haut (w = 1).
Le poids reste presque nul sur la première moitié de la couche, puis bascule vite : entre 0 et 2000 m, le vent garde 94 % de l'écart côté bas à 700 m MSL, et 63 % à 1000 m MSL.
Au-dessous de 0 m MSL le vent vaut `V0`, au-dessus de 8000 m il vaut `V2`.
Le mélange porte sur les composantes (nord, est), pas sur l'angle : le vent ne tourne pas, il passe d'un vecteur à l'autre.

### 2.3 Réduction près du sol

Sous 500 m de hauteur, le vecteur de l'étape 2.2 est multiplié par :

```
F = (h / 500) ^ p
p = 0,2 × (0,9957 − 0,001844·a + 1,379·10⁻⁶·a² − 3,592·10⁻¹⁰·a³)
a = altitude MSL du point, bornée à [0 ; 1500] m
```

`F = 1` à partir de 500 m de hauteur, `F = 0` au sol et dessous.
L'exposant `p` vaut 0,195 au niveau de la mer, 0,073 à 500 m et 0,024 à 1500 m d'altitude : **plus le terrain est haut, plus le profil est plat**, donc plus le vent au sol est proche du vent de référence.

La hauteur `h` ne sert qu'à cette réduction ; tout le reste se calcule en altitude MSL.

### 2.4 Rapport entre le vent réel et le réglage « au sol »

Le tableau donne `2,1411 × F`, c'est-à-dire le rapport entre le vent réel et `atGround` quand le niveau 2000 m pèse peu (terrain bas, ou `at2000` proche de 2,14 × `atGround`).
Au-dessus de 700 m MSL environ, il faut ajouter le raccord vers `at2000` : utiliser l'outil.

| Altitude du terrain | à 10 m | à 30 m | à 100 m | à 300 m |
|---|---|---|---|---|
| 0 m | 1,00 | 1,26 | 1,64 | 2,02 |
| 250 m | 1,34 | 1,55 | 1,82 | 2,07 |
| 500 m | 1,61 | 1,76 | 1,94 | 2,09 |
| 750 m | 1,78 | 1,89 | 2,01 | 2,11 |
| 1000 m | 1,87 | 1,95 | 2,04 | 2,11 |
| 1500 m et plus | 1,95 | 2,00 | 2,06 | 2,12 |

## 3. Ce qui compte et ce qui ne compte pas

### 3.1 Ce qui compte

- La vitesse au sol, linéairement : doubler `atGround` double exactement le vent sous 2000 m (mesuré : rapport 2,0000 ± 0,00002).
- L'altitude MSL du point, pour l'exposant `p` et pour le raccord entre niveaux.
- La hauteur au-dessus du sol, sous 500 m.

### 3.2 Ce qui ne compte pas pour le vent de base

Mesuré (mission 4 contre mission 1, écart 0,000000 m/s sur 5 392 points) :

- la turbulence `groundTurbulence` ;
- la température ;
- la saison (mois de la mission).

Le type de terrain (mer, ville, forêt) n'apparaît nulle part dans le calcul : seule l'altitude du sol intervient.

### 3.3 Directions différentes : une couche sans vent

Mission 3 : vent sol vers le nord, vent à 2000 m vers le sud, 10 m/s chacun.
Au-dessus de la mer, mesuré :

| Altitude MSL | Vitesse | Le vent souffle vers |
|---|---|---|
| 500 m | 21,2 m/s | le nord |
| 1000 m | 9,9 m/s | le nord |
| 1250 m | 1,5 m/s | le sud |
| 1500 m | 8,1 m/s | le sud |
| 2000 m | 10,0 m/s | le sud |

Le vent ne tourne pas progressivement : il faiblit, s'annule vers 1100-1200 m et repart dans l'autre sens.
Par le calcul (non mesuré), un écart de 90° produit le même phénomène en moins marqué : un creux de vitesse et une rotation concentrée sur quelques centaines de mètres.

### 3.4 La turbulence

`atmosphere.getWind` renvoie le vent de base décrit ici.
`atmosphere.getWindWithTurbulence` y ajoute une turbulence, présente même avec `groundTurbulence = 0` : DCS impose un plancher de 2 % du vent de référence `V0`.
Écart quadratique moyen mesuré entre les deux fonctions, sur 300 points espacés de 7 m :

| Hauteur sol | 10 m/s, turbulence 0 | 10 m/s, turbulence 60 (6 m/s) |
|---|---|---|
| 10 m | 0,66 m/s (max 1,1) | 3,2 m/s (max 5,6) |
| 100 m | 0,28 m/s | 3,0 m/s |
| 500 m | 0,73 m/s | 2,5 m/s |
| 1000 m | 2,1 m/s | 2,5 m/s |
| 2000 m | 0 | 0 |

Le détail du calcul de la turbulence (couches de 20 à 1620 m, décroissance en cosinus jusqu'à 1500 m) a été lu dans le code mais pas modélisé : il ne change pas le vent moyen à annoncer dans un brief.

## 4. Le champ « 500 m » de l'éditeur de mission

L'éditeur affiche, sous le vent au sol, une valeur « à 500 m » qu'il recalcule à chaque modification.
Elle vient de la fonction `updateSpeedDirForOtherLevel(11, 500, vitesse, direction)` du module Lua `Weather` (fichier `MissionEditor/modules/me_weather.lua`).
Appelée en jeu, cette fonction renvoie un entier arrondi, calculé au niveau de la mer et avec un vent nul à 2000 m :

| Vent sol réglé | Valeur affichée à 500 m |
|---|---|
| 5 m/s | 11 m/s |
| 9 m/s | 19 m/s |
| 10 m/s | 21 m/s |
| 20 m/s | 43 m/s |

C'est un bon ordre de grandeur du maximum de vent en basse couche au bord de mer, mais il ignore `at2000` et le relief.
Saisir une valeur dans ce champ recalcule le vent au sol à l'inverse.

## 5. Mesures

Cinq relevés, chacun de 5 392 points : les 225 aérodromes de la carte Syria et cinq points géographiques (mer Méditerranée, mer Morte, lac de Tibériade, mont Hermon à 2797 m, Qurnat as Sawda à 2964 m), de −5 à 5000 m de hauteur, plus deux profils MSL de −500 à 12 000 m par pas de 250 m.
La mer Morte et le lac de Tibériade sont sortis à 3 m d'altitude dans DCS : aucun sol sous le niveau de la mer n'a donc été mesuré.

| Relevé | Réglage (sol / 2000 / 8000, m/s) | Question | Écart maximal au modèle |
|---|---|---|---|
| 0-marteau-5-8-14 | 5 / 8 / 14, du 270 | modèle sur une météo réelle | 0,0000 m/s |
| 1-reference | 10 / 0 / 30, du 270 | forme du profil, raccords | 0,0002 m/s |
| 2-double | 20 / 0 / 30, du 270 | linéarité | 0,0003 m/s |
| 3-opposes | 10 vers le nord / 10 vers le sud / 10 vers le sud | mélange vectoriel ou angulaire | 0,0002 m/s |
| 4-turbulence-hiver | 10 / 0 / 30, turbulence 60, décembre, −10 °C | turbulence, saison, température | 0,0002 m/s |

Les écarts résiduels viennent de l'arrondi des relevés à 10⁻⁵ m/s.
La composante verticale du vent de base est toujours nulle.
La mission 4 demandait −10 °C en décembre ; DCS a chargé 5 °C (bornage probable de la température selon le mois, non étudié).
La température décroît de 6,5 °C par 1000 m entre 0 et 2000 m, dans les deux saisons.

Les relevés bruts sont dans [dcs-wind-model/data/](dcs-wind-model/data/).

## 6. Ce qu'en fait VMCT

`veafWeather.lua` ne recalcule pas le vent : il interroge `atmosphere.getWind` au point voulu.

- **ATIS et rapport météo d'un aérodrome** : vent à 10 m au-dessus du sol du point de l'aérodrome, la définition météorologique du vent de surface. Mesuré à Rosh Pina (réglage 5 m/s) : VMCT annonce 13 kt, DCS simule 13,1 kt.
- **LASTE** (A-10) : vent et température à l'altitude du terrain + 2000, 8000 et 16 000 ft, arrondie au millier de pieds, en direction magnétique.

Ces valeurs sont justes vis-à-vis du modèle.
Deux détails : la vitesse est tronquée au nœud inférieur (`math.floor`) plutôt qu'arrondie, et les rafales (`getWindWithTurbulence`) ne sont pas annoncées.
La fonction METAR est en commentaire et n'est pas utilisée.

## 7. Écrire un brief juste

L'outil [dcs_wind.py](dcs-wind-model/dcs_wind.py) lit la météo d'un `.miz` et donne le vent réel au-dessus d'un terrain, sans lancer DCS :

```
python dcs_wind.py VEAF_Syria_MarteauDuGolan_20261030_TRAINING.miz --elev-ft 860
```

```
Réglage de la mission : atGround 9 m/s (17 kt) du 270, at2000 11 m/s (21 kt) du 270, at8000 14 m/s (27 kt) du 270
Terrain à 262 m (860 ft)

  hauteur sol        altitude        vent (du / kt)
  10 m (vent au sol)    893 ft MSL   270 /   24
  100 ft                960 ft MSL   270 /   27
  300 ft               1160 ft MSL   270 /   32
  500 ft               1360 ft MSL   270 /   34
  1000 ft              1860 ft MSL   270 /   36
  ...
```

Pour viser un vent au sol donné sur un terrain d'altitude connue, diviser par le rapport du tableau 2.4 : pour 15 kt à 10 m sur un terrain à 250 m, régler 15 / 1,34 ≈ 11 kt (5,8 m/s).
Ne pas oublier que le vent vers 1000 ft sol vaudra alors environ 2,1 × 11 ≈ 24 kt.

## 8. Refaire les mesures

Les scripts sont dans [dcs-wind-model/](dcs-wind-model/) :

- `make_missions.py` écrit les quatre missions de test à partir de la mission d'arpentage vide de veaf-tools (`veaf-survey-Syria.miz`, dcs-bridge chargé au démarrage) en ne changeant que la météo ;
- `measure.py <nom>` interroge la mission lancée par `dcs-serve`, lit la météo dans `env.mission.weather`, enregistre le relevé et affiche l'écart au modèle ; `--me` appelle aussi la fonction du champ « 500 m » (il faut un `MissionScripting.lua` désanitisé pour `require`) ;
- `dcs_wind.py` contient le modèle.

Protocole : générer les missions, lancer `dcs-serve`, charger chaque mission dans DCS jusqu'à la carte, lancer `measure.py`.
Une mission redémarrée par réglage : DCS ne permet pas de changer la météo statique en cours de mission.

## 9. Comment le modèle a été trouvé

Le code de la météo est dans `bin/Weather.dll`, dont les exports C++ portent des noms explicites (`Weather::StaticAtmosphere`, `IAtmosphere`).
Le désassemblage (Capstone, script [pedis.py](dcs-wind-model/pedis.py)) de quatre fonctions suffit :

| Fonction | Rôle |
|---|---|
| `reconfigureAtmosphere` | lit `atGround`, `at2000`, `at8000` dans la mission et pose les points à 0, 2000 et 8000 m |
| `StaticAtmosphere::addPointGroundWind_w` | multiplie le vent sol par `pow(45, 0.2)` et le pose au niveau 0 m |
| `StaticAtmosphere::getBaseWind_w` | choisit les deux niveaux, calcule `exp(−s⁴)`, applique le facteur sol |
| `IAtmosphere::getWindGroundFactor` | `pow(h/500, p)` avec le polynôme en altitude |

`IAtmosphere::getGroundWind_w`, utilisée par l'interface, évalue le vent de base à 11 m de hauteur.
Les mesures en jeu ont servi à confirmer ce que le code disait, pas à ajuster des constantes.

## 10. Limites

- **Météo statique seulement.** La météo dynamique (`atmosphere_type = 1`, systèmes de pression) passe par `DynamicAtmosphere::getBaseWind_w`, non étudiée.
- **Une version, une carte.** DCS 2.9.31.29434, carte Syria ; le calcul ne dépend pas de la carte, mais une mise à jour de `Weather.dll` peut le changer. Un relevé `measure.py` suffit à le vérifier.
- **Sol sous le niveau de la mer non mesuré.** Le code y applique le vent `V0` avec l'exposant du niveau de la mer.
- **Mesures en solo**, sur le moteur de mission. Le vent ressenti par un avion passe par le même code, mais n'a pas été mesuré séparément.
- **La turbulence** n'est que caractérisée (section 3.4), pas modélisée.
