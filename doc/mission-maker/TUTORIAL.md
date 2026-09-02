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

Créez un dossier vide pour votre mission. Téléchargez
`veaf-tools-updater.exe` depuis la
[dernière release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest),
posez-le dedans, et lancez-le :

```powershell
.\veaf-tools-updater.exe
```

> **Le `.\` n'est pas décoratif.** Le terminal Windows par défaut est **PowerShell**, et PowerShell
> ne cherche pas dans le dossier courant — exprès, pour qu'un exécutable déposé là ne prenne pas la
> place d'une vraie commande. Sans le `.\`, il répond que `veaf-tools-updater.exe` « is not
> recognized », en désignant le fichier que vous avez sous les yeux. L'invite de commandes
> (`cmd.exe`) accepte les deux formes, donc `.\` marche partout : c'est la forme écrite partout dans
> cette documentation. Détails et autres écarts entre les deux shells :
> [PowerShell ou invite de commandes ?](GUIDE.md#powershell-vs-cmd).

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
.\veaf-tools.exe prepare --template standard --theatre Caucasus
```

**Ce qui doit se passer** : douze fichiers sont posés, plus `ctld-config.yaml`, et le message se
termine par

> Dossier de mission prêt : … Ensuite : placez/extrayez votre .miz dans src/mission, puis
> `veaf-tools validate` et `veaf-tools build`.

`--theatre Caucasus` pose une mission Caucase vierge dans `src/mission` : vous pouvez construire
tout de suite, sans passer par DCS.

`--template standard` choisit le jeu de modules de ce tutoriel : les modules dont vous aurez besoin
sont déjà écrits dans `mission.yaml`, ceux qui demandent une configuration étant livrés **en
commentaire**, prêts à activer. `minimal` en pose moins — trop peu pour l'étape 8, où vous auriez
un bloc à écrire de zéro ; `full` en pose davantage.

!!! note "Relancer `prepare` plus tard"
    Sur un dossier déjà préparé, `prepare` demande fichier par fichier s'il faut **remplacer** ou
    **garder** — avec un « tout remplacer » et un « tout garder ». Répondez *garder* pour
    `mission.yaml` : c'est le fichier que vous éditez à la main, et le seul dont le contenu est le
    vôtre. Le template n'est alors pas appliqué, et l'outil vous le dit.

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
  # ── Features ──
  NAMEDPOINTS: true
  MOVE: true
  GRASS: true
  WEATHER: true
  REMOTE: true
  AIRBASES: true
  # ── Combat ──
  GROUNDAI: true  # ground units AI behaviour (required by CASMISSION)
  CASMISSION: true  # `_cas` marker (no config)
  TRANSPORTMISSION: true  # `_transport` marker (no config)
  CARRIER: true  # carrier-operations radio menus
  #   COMBATZONE:
  #     enabled: true
  #     combat_zones:
  #       - type: zone
  #         zone_name: CZ-Alpha
  #         friendly_name: Alpha Zone
  #         training: false
```

(Suivent un bloc `QRA` commenté et une rubrique `# ── Community ──` — on y reviendra à l'étape 8 et
à l'étape 6.)

Trois formes de module cohabitent, et la différence compte :

| Forme | Ce que ça veut dire |
|---|---|
| `UNITS:` — rien après le deux-points | infrastructure, toujours là, rien à configurer |
| `RADIO: true` | un interrupteur : le module marche tel quel |
| `#   COMBATZONE:` — un bloc commenté | le module demande une configuration ; l'exemple est prêt à décommenter |

Changez le nom, et **coupez la sécurité le temps d'apprendre** :

```yaml
mission:
  name: Mon-Premier-Vol

security:
  disabled: true
```

Puis, **si vous n'avez pas de serveur SRS**, éteignez la synthèse vocale tout de suite : trouvez la
ligne `STTS: true` sous `# ── Community ──`, et passez-la à `false`.

```yaml
  STTS: false
```

Sans SRS, STTS n'a rien à faire — autant ne pas l'allumer pendant que vous apprenez. Si vous ne
savez pas ce qu'est SRS, c'est que vous n'en avez pas : mettez `false`.

Le reste du fichier — en-têtes de rubriques, options de `mission:`, blocs de modules à configurer —
est commenté : ce sont des exemples prêts à décommenter, pas de la configuration active.

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

**Ce qui doit se passer** : le build annonce la génération de `veaf-config.lua`, **la liste des
modules qu'il a lus**, l'injection des déclencheurs, puis les étapes du pipeline. Il se termine par
« Traitement terminé ! ».

> Modules VEAF actifs (22) : AIRBASES, CACHE, CARRIER, CASMISSION, COMMANDS, CSAR, CTLD, EVENTS,
> GRASS, GROUNDAI, INTERPRETER, MARKERS, MOVE, NAMEDPOINTS, RADIO, REMOTE, SHORTCUTS, SPAWN, TIME,
> TRANSPORTMISSION, UNITS, WEATHER

Cette ligne est votre accusé de réception : un module que vous venez d'ajouter et qui n'y figure pas
n'a pas été lu. Les modules qui portent une liste affichent leur nombre d'entrées — vous verrez
`COMBATZONE (1)` apparaître à l'étape 8.

Le nombre total dépend de ce que vous avez éteint : 22 ici parce que `STTS` est passé à `false` à
l'étape 2, 23 si vous l'avez laissé allumé.

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

!!! tip "Écrivez toujours le `.miz`"
    Le nom que vous donnez n'est conservé **que** s'il se termine par `.miz`. `build Mon-Premier-Vol`
    — sans extension — et `build` tout court écrivent `Mon-Premier-Vol_AAAAMMJJ.miz`, avec la date
    du jour. Utile pour archiver une version, déroutant pendant le tutoriel : vous chercheriez « le
    fichier de la racine » sans le reconnaître. Détail :
    [fiche : le build](concepts/build.md).

Ce `.miz` n'a encore **aucune place joueur** : ne cherchez pas à le voler, c'est l'objet de l'étape
suivante. Ce que vous venez de vérifier, c'est que la chaîne de build fonctionne de bout en bout
sans avoir lancé DCS une seule fois.

---

## Étape 5 — Ajouter une place joueur {#step-5-slot}

La mission vierge n'a personne dedans. C'est maintenant que DCS entre en scène.

**Ne créez pas de nouvelle mission** : ouvrez celle que vous venez de construire. Dans l'**éditeur
de mission de DCS**, ouvrez `Mon-Premier-Vol.miz`, à la racine de votre dossier de mission, et
ajoutez-y un vol jouable :

- un appareil que vous possédez, coalition bleue ;
- **au parking, moteur froid** — un départ en vol rend les vérifications suivantes malcommodes ;
- compétence **Client**.

Enregistrez (sous le même nom, au même endroit), puis revenez à la console :

```powershell
.\veaf-tools.exe extract Mon-Premier-Vol.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build Mon-Premier-Vol.miz
```

`extract` remplace le `src/mission` vierge par votre vraie mission ; `build` la reconstruit avec les
scripts VEAF. C'est la boucle dans laquelle vous allez vivre : **éditeur → `extract` → `build`**.
Elle est rejouable autant de fois que vous voulez — le build retire les déclencheurs VEAF avant d'en
réinjecter, donc rien ne s'accumule. C'est pour ça qu'on rouvre le `.miz` construit au lieu d'en
refaire un : votre travail d'éditeur et celui du build se superposent sans se marcher dessus.

**Comment savoir** : `validate` ne se plaint plus de l'absence de place joueur.

!!! tip "Le fichier à rouvrir dans l'éditeur"
    C'est toujours celui de la **racine** du dossier : c'est lui que l'éditeur écrit et que le build
    réécrit. Les variantes de `missions/` sont des produits — ne les rouvrez pas pour éditer.

---

## Étape 6 — Voler, et trouver le menu VEAF {#step-6-fly}

Lancez `Mon-Premier-Vol.miz` dans DCS, prenez le slot, et ouvrez le menu radio : **F10 « Other »**.

**Ce que vous devez voir** : une entrée **VEAF**. Elle n'existe que parce que `RADIO: true` est dans
votre `mission.yaml`.

Le menu en contient d'autres — le template `standard` active aussi CTLD (logistique et transport
d'hélicoptères) et CSAR (récupération de pilotes). Ce tutoriel ne se sert que de l'entrée VEAF ;
vous pouvez éteindre les autres comme vous l'avez fait pour STTS à l'étape 2, en passant leur ligne
à `false` dans `mission.yaml`.

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
mécanique, vous allez le remplacer par le plus petit fichier qui fonctionne — donc **mettez-le de
côté avant** :

```powershell
Copy-Item src\presets.yaml src\presets.yaml.bak
```

Puis remplacez son contenu par :

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

Restaurez ensuite le fichier livré — il contient déjà les aérodromes du Caucase et les fréquences
d'agence usuelles, et c'est celui avec lequel vous voudrez travailler :

```powershell
Copy-Item src\presets.yaml.bak src\presets.yaml -Force
```

!!! note "La façon dont les vrais projets font ça"
    Copier un fichier avant de le modifier marche, mais ça ne passe pas l'échelle : au bout de
    quelques semaines, une mission est faite d'une dizaine de fichiers qui évoluent ensemble, et
    « revenir à avant-hier » devient impossible à la main. Les outils de **gestion de versions**
    répondent exactement à ça : ils gardent l'historique complet du dossier, permettent de comparer
    deux états et de revenir à n'importe lequel, et rendent le travail à plusieurs possible.

    Le standard de fait s'appelle **Git**. Ce n'est pas nécessaire pour finir ce tutoriel, et c'est
    un outil à part entière qui s'apprend pour lui-même — mais dès que votre mission compte,
    c'est le prochain investissement rentable. Pour commencer :
    [Pro Git, en français](https://git-scm.com/book/fr/v2), gratuit et complet.

→ [fiche : préréglages radio](concepts/radio-presets.md)

---

## Étape 8 — Un objectif activable en jeu {#step-8-combat-zone}

C'est le morceau qui donne à une mission VEAF son intérêt : un objectif qui n'existe que quand
quelqu'un le demande.

**Dans l'éditeur DCS** :

1. créez une trigger zone nommée `CZ-Alpha` ;
2. placez dedans un groupe rouge de véhicules, nommé `CZ-Alpha-ARMOR`.

**Dans `mission.yaml`**, trouvez le bloc `COMBATZONE` sous la rubrique `# ── Combat ──`. Il est
livré en commentaire, avec le bon exemple :

```yaml
  #   COMBATZONE:
  #     enabled: true
  #     combat_zones:
  #       - type: zone
  #         zone_name: CZ-Alpha
  #         friendly_name: Alpha Zone
  #         training: false
```

Décommentez-le, puis passez `training` à `true` :

```yaml
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: CZ-Alpha
        friendly_name: Alpha Zone
        training: true
```

!!! warning "Décommenter, c'est retirer le `#` **et les trois espaces qui le suivent**"
    Sur chaque ligne du bloc, supprimez exactement `#` plus trois espaces — jamais les espaces du
    début de ligne. En YAML, l'indentation *est* la structure : `  COMBATZONE:` à deux espaces
    appartient à `modules:`, à zéro espace il devient un bloc de premier niveau que rien ne lit.
    C'est pour ça que le bloc livré est indenté comme il l'est : la soustraction tombe juste.

Puis la boucle habituelle :

```powershell
.\veaf-tools.exe extract Mon-Premier-Vol.miz
.\veaf-tools.exe validate
.\veaf-tools.exe build Mon-Premier-Vol.miz
```

`validate` vous dira si `CZ-Alpha` n'existe pas dans la mission — c'est exactement le genre d'erreur
qu'il est là pour attraper.

**Comment savoir, avant de lancer DCS** : deux signes, dans cet ordre.

1. `validate` annonce **0 erreur** : la zone que vous avez nommée existe bien dans la mission.
2. Le build liste vos modules actifs, et `COMBATZONE` y porte maintenant son nombre de zones :

> Modules VEAF actifs (23) : AIRBASES, CACHE, CARRIER, CASMISSION, **COMBATZONE (1)**, COMMANDS, …

Si vous lisez `COMBATZONE (0)`, le module est actif mais votre liste `combat_zones:` n'a rien donné
— une erreur d'indentation, presque toujours. Si `COMBATZONE` n'apparaît pas du tout, le bloc n'est
pas dans `modules:`.

**En jeu** : la zone est **vide** au démarrage, c'est voulu. Allez dans
**F10 « Other » → ZONES DE COMBAT → Alpha Zone → Activer la zone**.

**Ce que vous devez voir** : le message « VeafCombatZone Alpha Zone a été activé. », puis vos
blindés qui apparaissent, puis le rapport de zone.

!!! danger "Le piège qui coûte une heure"
    Un groupe n'est capturé par la zone que si **son nom commence par le nom de la zone**. Placé au
    bon endroit mais nommé `ARMOR-1`, il est ignoré. Il faut `CZ-Alpha-ARMOR-1`.

→ [fiche : zones de combat](concepts/combat-zones.md)

---

## Étape 9 — Ouvrir un terrain aux slots dynamiques {#step-9-dynamic-slots}

Cette étape est souvent **déjà faite**, et c'est normal : en posant votre appareil bleu au parking
d'un aérodrome à l'étape 5, vous avez donné cet aérodrome à la coalition bleue. Vérifiez-le dans
l'éditeur DCS, et ne changez rien si c'est le cas — c'est la seule chose à y faire, le reste est
écrit par le build.

`src/warehouses.yaml` n'a pas besoin d'être touché non plus : livré tel quel, il active les slots
dynamiques sur **tout** aérodrome appartenant à une coalition. Sous ses commentaires, il tient en
deux blocs :

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

Si vous avez changé quelque chose dans l'éditeur, refaites `extract` puis `build`. Si tout était
déjà en place, il n'y a rien à reconstruire : passez directement à la vérification.

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
