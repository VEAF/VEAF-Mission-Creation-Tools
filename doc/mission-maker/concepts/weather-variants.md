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
position:                    # requis par les expressions solaires
  latitude: 33.5
  longitude: 35.5
  timezone: "Asia/Damascus"

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

- **Heures** : `"HH:MM"`, une expression solaire (`sunrise`, `sunset-30*60`), ou des secondes.
- **Dates** : `"AAAA-MM-JJ"`, `today`, `tomorrow`, `+N` / `-N` jours.
- **`metar:`** remplace le bloc `weather:` par une observation réelle.

## Le piège {#gotcha}

**Le fichier est livré non vide, donc l'étape s'exécute dès le premier build.** Votre première
mission produit deux `.miz` sans que vous ayez rien demandé : celui de la racine et
`missions/…_noon.miz`. Ce n'est pas un doublon — le second porte la météo.

Deuxième piège : une expression solaire sans bloc `position:` est **ignorée en silence**. Si votre
variante « aube » sort à l'heure de base, c'est là qu'il faut regarder.

Pour couper l'étape entièrement :

```yaml
pipeline:
  weather: false
```

## Pour aller plus loin {#more}

- [Référence Pipeline — étape 6, variantes météo et horaire](../../PIPELINE_REFERENCE.md#pipeline-step-6-versions)
- [Référence Pipeline — afficher la météo dans le briefing](../../PIPELINE_REFERENCE.md#briefing-variables)
- [veafWeather](../scripts/veafWeather.md) — la météo en jeu, côté joueur
