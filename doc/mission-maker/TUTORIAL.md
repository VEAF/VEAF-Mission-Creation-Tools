# Tutoriel — votre première mission

Un fil unique, du dossier vide à une mission qui tourne. Vous savez utiliser l'éditeur de mission de
DCS ; vous n'avez jamais ouvert VMCT.

Chaque étape dit **quoi taper**, **ce qui doit se passer**, et **comment savoir que ça a marché**.
Les explications de fond ne sont pas ici : chaque concept renvoie à [sa fiche](concepts/README.md)
au moment où il sert. Si vous voulez d'abord la vue d'ensemble, lisez
[Découvrir VMCT en dix minutes](DISCOVER.md).

Comptez une heure, dont la moitié dans DCS.

---

## Étape 0 — Installer les outils {#step-0-install}

Créez un dossier vide pour votre mission — ce sera votre dépôt Git. Téléchargez
`veaf-tools-updater.exe` depuis la
[dernière release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest),
posez-le dedans, et lancez-le :

```powershell
.\veaf-tools-updater.exe
```

> Windows bloque parfois un `.exe` téléchargé : clic droit → **Propriétés** → cocher **Débloquer**.

**Ce qui doit se passer** : un dossier `published/` apparaît, et `veaf-tools.exe` à côté de
l'updater.

**Comment savoir** :

```powershell
.\veaf-tools.exe about
```

affiche la version installée.

---

## Étape 1 — Créer le dossier de mission {#step-1-prepare}

```powershell
.\veaf-tools.exe prepare --template minimal --theatre Caucasus
```

**Ce qui doit se passer** : douze fichiers sont posés, et le message se termine par

> Dossier de mission prêt : … Ensuite : placez/extrayez votre .miz dans src/mission, puis
> `veaf-tools validate` et `veaf-tools build`.

`--theatre Caucasus` pose une mission Caucase vierge dans `src/mission` : vous pouvez construire
tout de suite, sans passer par DCS. `--template minimal` choisit le plus petit jeu de modules ;
`standard` et `full` en activent davantage.

**Comment savoir** : `src/mission/mission` existe, et `mission.yaml` est à la racine.

→ [fiche : le dossier de mission](concepts/mission-folder.md)

---

## Étape 2 — Regarder ce qui a été généré {#step-2-look}

Ouvrez `mission.yaml`. L'essentiel tient en deux blocs :

```yaml
mission:
  name: "My-Mission"

modules:
  # ── Infrastructure ──
  UNITS:
  TIME:
  CACHE:
  EVENTS:
  MARKERS:
  COMMANDS:
  # ── Core ──
  RADIO: true  # the VEAF F10 radio menu
  SPAWN: true
  SHORTCUTS: true  # built-in aliases (-shilka, -sa2, …)
  INTERPRETER: true
```

Changez le nom, et **coupez la sécurité le temps d'apprendre** :

```yaml
mission:
  name: Mon-Premier-Vol

security:
  disabled: true
```

Tout le reste du fichier est commenté : ce sont des exemples prêts à décommenter, pas de la
configuration active.

!!! warning "`security: disabled: true` n'est pas facultatif ici"
    Par défaut, la sécurité VEAF est **active** : la plupart des commandes de marqueur et les
    activations de zone de combat exigent alors une radio authentifiée ou un mot de passe. En solo,
    hors serveur, ça se manifeste par des commandes qui ne font rien — et on cherche le bug
    ailleurs. Le bloc `security:` va à la **racine** du fichier, pas dans `modules:`. Remettez-la
    avant de déployer sur un serveur.

→ [fiche : `mission.yaml` et ses modules](concepts/mission-yaml.md) ·
[veafSecurity](scripts/veafSecurity.md)

---

## Étape 3 — Vérifier avant de construire {#step-3-validate}

```powershell
.\veaf-tools.exe validate
```

**Ce qui doit se passer** : trois avertissements, zéro erreur.

> ⚠ Aucune place joueur dans la mission (aucune unité en compétence Client ou Player)…
> ⚠ presets.yaml est configuré mais la mission n'a aucun aéronef joueur…
> ⚠ waypoints.yaml est configuré mais la mission n'a aucun groupe d'aéronefs…
> Validation : 0 erreurs, 3 avertissements.

C'est normal : la mission est vide. Les avertissements décrivent exactement ce que vous allez
ajouter aux étapes suivantes.

---

## Étape 4 — Construire {#step-4-build}

```powershell
.\veaf-tools.exe build Mon-Premier-Vol.miz
```

**Ce qui doit se passer** : le build annonce la génération de `veaf-config.lua`, l'injection des
déclencheurs, puis les étapes du pipeline. Il se termine par « Traitement terminé ! ».

**Comment savoir** : **deux** fichiers sont apparus.

| Fichier | Ce que c'est |
|---|---|
| `Mon-Premier-Vol.miz` | la mission de base |
| `missions/Mon-Premier-Vol_noon.miz` | la variante « midi », produite par `src/versions.yaml` |

Ce n'est pas un doublon : c'est l'étape météo qui a trouvé son fichier de configuration.

→ [fiche : le build](concepts/build.md) · [fiche : variantes météo](concepts/weather-variants.md)

!!! warning "Lancez `veaf-tools.exe` depuis le dossier de mission"
    Les scripts et le fichier produit sont résolus depuis le dossier courant. Lancé d'ailleurs, il
    cherche `published/` au mauvais endroit.

Ce `.miz` n'a encore **aucune place joueur** : ne cherchez pas à le voler, c'est l'objet de l'étape
suivante. Ce que vous venez de vérifier, c'est que la chaîne de build fonctionne de bout en bout
sans avoir lancé DCS une seule fois.

---

## Étape 5 — Ajouter une place joueur {#step-5-slot}

La mission vierge n'a personne dedans. C'est maintenant que DCS entre en scène.

Dans l'**éditeur de mission de DCS**, créez une mission sur le Caucase avec un vol jouable :

- un appareil que vous possédez, coalition bleue ;
- **au parking, moteur froid** — un départ en vol rend les vérifications suivantes malcommodes ;
- compétence **Client**.

Sauvegardez-la sous le nom `Mon-Premier-Vol.miz`, **dans votre dossier de mission**, puis revenez à
la console :

```powershell
.\veaf-tools.exe extract Mon-Premier-Vol.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build Mon-Premier-Vol.miz
```

`extract` remplace le `src/mission` vierge par votre vraie mission ; `build` la reconstruit avec les
scripts VEAF. C'est la boucle dans laquelle vous allez vivre : **éditeur → `extract` → `build`**.
Elle est rejouable autant de fois que vous voulez — le build retire les déclencheurs VEAF avant d'en
réinjecter, donc rien ne s'accumule.

**Comment savoir** : `validate` ne se plaint plus de l'absence de place joueur.

!!! tip "Le fichier à rouvrir dans l'éditeur"
    C'est toujours celui de la **racine** du dossier : c'est lui que l'éditeur écrit et que le build
    réécrit. Les variantes de `missions/` sont des produits — ne les rouvrez pas pour éditer.

---

## Étape 6 — Voler, et trouver le menu VEAF {#step-6-fly}

Lancez `Mon-Premier-Vol.miz` dans DCS, prenez le slot, et ouvrez le menu radio : **F10 « Other »**.

**Ce que vous devez voir** : une entrée **VEAF**. Elle n'existe que parce que `RADIO: true` est dans
votre `mission.yaml`.

Essayez ensuite un marqueur : posez un marqueur sur la carte F10 et donnez-lui pour texte l'alias

```
-shilka
```

Une ZSU-23-4 Shilka apparaît à l'endroit du marqueur. Ça, c'est `SPAWN: true` plus `SHORTCUTS: true`
— et la sécurité coupée à l'étape 2. La forme longue de la même commande est
`_spawn unit, name ZSU-23-4 Shilka`.

**Si le menu VEAF n'est pas là** : les scripts ne se sont pas chargés. Le journal de DCS le dit —
voir [lire les journaux DCS](LOGS.md).

→ [alias de marqueurs](../ALIASES.md) · [veafSpawn](scripts/veafSpawn.md)

---

## Étape 7 — Donner les mêmes radios à tout le monde {#step-7-presets}

Ouvrez `src/presets.yaml` : il est livré avec un plan complet pour le Caucase. Pour comprendre la
mécanique, remplacez-le d'abord par le plus petit fichier qui fonctionne :

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

channel_lists:
  blue:
    primary_1:
      01: Guard
```

Reconstruisez, et rouvrez la mission en jeu.

**Comment savoir** : le canal 1 de la première radio de votre appareil est sur 243.0, et une
planchette « presets » est disponible dans le cockpit.

Vous pouvez ensuite restaurer le fichier livré (`git checkout src/presets.yaml`, ou une nouvelle
`prepare`) : il contient déjà les aérodromes du Caucase et les fréquences d'agence usuelles.

→ [fiche : préréglages radio](concepts/radio-presets.md)

---

## Étape 8 — Un objectif activable en jeu {#step-8-combat-zone}

C'est le morceau qui donne à une mission VEAF son intérêt : un objectif qui n'existe que quand
quelqu'un le demande.

**Dans l'éditeur DCS** :

1. créez une trigger zone nommée `CZ-Alpha` ;
2. placez dedans un groupe rouge de véhicules, nommé `CZ-Alpha-ARMOR`.

**Dans `mission.yaml`**, décommentez le bloc `COMBATZONE` et réduisez-le à :

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Zone Alpha
        training: true
```

Puis la boucle habituelle :

```powershell
.\veaf-tools.exe extract Mon-Premier-Vol.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build Mon-Premier-Vol.miz
```

`validate` vous dira si `CZ-Alpha` n'existe pas dans la mission — c'est exactement le genre d'erreur
qu'il est là pour attraper.

**En jeu** : la zone est **vide** au démarrage, c'est voulu. Allez dans
**F10 « Other » → ZONES DE COMBAT → Zone Alpha → Activer la zone**.

**Ce que vous devez voir** : le message « VeafCombatZone Zone Alpha a été activé. », puis vos
blindés qui apparaissent, puis le rapport de zone.

!!! danger "Le piège qui coûte une heure"
    Un groupe n'est capturé par la zone que si **son nom commence par le nom de la zone**. Placé au
    bon endroit mais nommé `ARMOR-1`, il est ignoré. Il faut `CZ-Alpha-ARMOR-1`.

→ [fiche : zones de combat](concepts/combat-zones.md)

---

## Étape 9 — Ouvrir un terrain aux slots dynamiques {#step-9-dynamic-slots}

**Dans l'éditeur DCS** : donnez un aérodrome à la coalition bleue. C'est la seule chose à y faire —
le reste est écrit par le build.

`src/warehouses.yaml` est déjà correct tel qu'il est livré :

```yaml
blue:
  defaults:
    fuel: unlimited
    weapons: unlimited

red:
  defaults:
    fuel: unlimited
    weapons: unlimited
```

Reconstruisez.

**Comment savoir** : dans DCS, à la sélection de slot, l'aérodrome propose des appareils en spawn
dynamique.

**Si la liste est plus courte que prévu** : DCS ne propose que ce que le parking du terrain peut
réellement accueillir. Un terrain qui n'a que des emplacements hélicoptères ne proposera pas
d'avions, quel que soit le stock.

→ [fiche : slots dynamiques](concepts/dynamic-slots.md)

---

## Étape 10 — Et ensuite {#step-10-next}

Vous avez une mission qui tourne, versionnable, reconstructible. La suite se choisit à la carte :

| Vous voulez | Allez à |
|---|---|
| Comprendre une pièce en particulier | [les fiches](concepts/README.md) |
| Ajouter des ravitailleurs, AWACS, porte-avions gérés | [veafAssets](scripts/veafAssets.md) |
| Une QRA qui décolle sur intrusion | [veafQraManager](scripts/veafQraManager.md) |
| Du combat aérien par vagues | [veafAirWaves](scripts/veafAirWaves.md) |
| Protéger votre serveur par mot de passe | [veafSecurity](scripts/veafSecurity.md) |
| Toutes les options de configuration | [Référence `mission.yaml`](../MISSION_YAML_REFERENCE.md) |
| Toutes les commandes | [Référence CLI](../CLI_REFERENCE.md) |
| Le détail de bout en bout | [Guide complet](GUIDE.md) |

Et gardez le réflexe : `validate` avant `build`, et [le journal de DCS](LOGS.md) quand quelque chose
ne se charge pas.
