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
