# Variantes météo

## Ce que c'est {#what-it-is}

`src/versions.yaml` décrit des couples **météo + horaire**. Le build écrit un `.miz` par entrée, à
côté de la mission de base, dans `missions/`. Une seule mission source, plusieurs ambiances.

## Le plus petit exemple qui marche {#minimal-example}

C'est le fichier livré, réduit à l'essentiel :

```yaml
versions:
  - name: noon
    time: "12:00"
    weather:
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0
      visibility: 10000.0
      cloud_type: "clear"
      fog_enabled: false
```

`build Ma-Mission.miz` produit alors `Ma-Mission.miz` **et** `missions/Ma-Mission_noon.miz`.

## Horaires solaires et météo réelle {#solar-and-metar}

```yaml
position:                    # facultatif : sinon, le point de la carte de la mission
  latitude: 41.93
  longitude: 41.86
  timezone: "Asia/Tbilisi"

base_date: "2024-03-15"

versions:
  - name: dawn
    time: "sunrise"

  - name: evening
    time: "sunset-30*60"     # 30 minutes avant le coucher

  - name: real-weather
    time: "14:00"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 BKN025 18/12 Q1018 NOSIG"
```

- **`position:`** dit où le lever et le coucher sont calculés.
  Sans elle, le build les calcule sur la carte de la mission, en un point par théâtre (vers Batoumi sur le Caucase, Hama sur la Syrie…) et le dit dans le journal.
  Sur une grande carte, une mission loin de ce point se décale de quelques minutes : donnez alors `position:` près de la mission.
  Une `position:` hors de la carte de la mission (la Damas de l'ancien fichier par défaut, restée dans une mission du Caucase) est signalée par un avertissement.
- **Heures** : `"HH:MM"`, une expression solaire (`sunrise`, `sunset-30*60`), ou des secondes.
  Toutes sont à l'**heure locale du théâtre**, celle que DCS affiche : chaque théâtre a un décalage
  fixe par rapport à UTC, sans heure d'été (Caucasus UTC+4, Syria UTC+3, GermanyCW UTC+2…). Le
  `timezone:` de `position` ne sert que pour un théâtre que l'outil ne connaît pas, et le build le
  signale.
- **Dates** : `"AAAA-MM-JJ"`, `today`, `tomorrow`, `+N` / `-N` jours.
- **`metar:`** remplace le bloc `weather:` par une observation réelle.

## Le vent {#wind}

**`wind_speed` et `wind_direction` sont le vent voulu à 10 m au-dessus d'un terrain de référence**, tel qu'un METAR ou l'ATIS le donnera là-bas — pas le réglage de l'éditeur de mission.
DCS multiplie son « vent au sol » par 2,14 au niveau de la mer, et le réduit près du sol d'autant moins que le terrain est haut : 9 m/s réglés (17 kt) ont soufflé 24 kt à 10 m au-dessus de Rosh Pina et 36 kt à 1 000 ft ([le modèle du vent de DCS](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/whitepapers/dcs-wind-model.fr.md)).
Le build écrit donc le réglage qui donne le vent voulu, et le journal dit pour quel terrain.

- **Le terrain de référence** est, dans l'ordre : la station du METAR quand elle est sur la carte ; sinon `reference_airfield` ; sinon le terrain de départ du premier groupe joueur ; sinon le niveau de la mer, avec un avertissement (le vent sera plus fort sur tout terrain à l'intérieur des terres).
- **En altitude**, le vent à 2 000 m vaut 2,2 fois le réglage au sol, tourné de 20° vers la droite (`wind_veer`, de 0 à 30°) ; à 8 000 m, 3 m/s de plus. Le vent ne fait ainsi que forcir avec la hauteur.
  `wind_speed_2000` / `wind_direction_2000` et `wind_speed_8000` / `wind_direction_8000` (d'où vient le vent, en degrés) les règlent à la main ; un vent à 2 000 m sous 2,14 fois le réglage au sol fait un jet entre 300 et 600 m sol, et le build le signale.
  Ne réglez jamais un vent d'altitude opposé à celui du sol : DCS fait entre les deux une couche sans vent.
- **`clearsky: true`** plafonne le vent voulu à 15 kt, donc le vent simulé au sol au terrain de référence, et retire les rafales.
- **Les rafales** : le groupe `G` d'un METAR (`27015G25KT`), ou `wind_gust` (m/s), devient la turbulence de DCS (`groundTurbulence`), d'après la mesure en jeu : un écart rafale − vent moyen de G demande une turbulence de G / 0,62, plafonnée à 3 m/s. `turbulence` (m/s, comme l'éditeur l'affiche) l'emporte sur la rafale.

```yaml
versions:
  - name: windy
    time: "10:00"
    weather:
      wind_speed: 7.7           # 15 kt à 10 m au-dessus de Rosh Pina
      wind_direction: 270.0
      reference_airfield: "Rosh Pina"
      wind_gust: 10.3           # 20 kt
```

Le briefing annonce le vent **simulé**, couche par couche : celui que donnent `inspect_built_mission` et le deck de briefing, et que `veaf-tools dcs mission-check` vérifie contre le briefing, sans DCS ([mission-check](../../CLI_REFERENCE.md#mission-check)).

## Le piège {#gotcha}

**Le fichier est livré non vide, donc l'étape s'exécute dès le premier build.** Votre première
mission produit deux `.miz` sans que vous ayez rien demandé : celui de la racine et
`missions/…_noon.miz`. Ce n'est pas un doublon — le second porte la météo.

Deuxième piège : jusqu'en 6.29, le `versions.yaml` livré écrivait une `position:` à Damas, quelle que soit la carte.
Une mission créée avant garde cette position, et son « aube » sur le Caucase arrive 25 à 50 minutes après le lever du soleil.
Retirez le bloc `position:` de votre `versions.yaml` : le build calcule alors sur la carte de la mission.

Pour couper l'étape entièrement :

```yaml
pipeline:
  weather: false
```

## Pour aller plus loin {#more}

- [Référence Pipeline — étape 6, variantes météo et horaire](../../PIPELINE_REFERENCE.md#pipeline-step-6-versions)
- [Référence Pipeline — afficher la météo dans le briefing](../../PIPELINE_REFERENCE.md#briefing-variables)
- [veafWeather](../scripts/veafWeather.md) — la météo en jeu, côté joueur
