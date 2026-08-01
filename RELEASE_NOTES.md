# VEAF Mission Creation Tools — 6.13.0

Une seule grande nouvelle dans cette version : **CTLD passe à la version 2**. Le script de
transport et de logistique embarqué par les outils n'est plus le monolithe historique de
ciribob mais la **réécriture VEAF** — même jeu, code modulaire et testé — et surtout, il ne se
configure plus dans `mission.yaml` mais dans un fichier dédié, avec un **éditeur graphique**.

> **CTLD embarqué : `2.0.0-rc3`.** C'est une *release candidate*, pas encore une version
> stable. Elle est éprouvée (plus de 1 100 tests automatiques et des tests en vol), mais si
> vous exploitez un serveur public, sachez sur quoi vous décollez.

---

## ⚠️ À lire avant de mettre à jour

**Si vos missions activent CTLD, elles demandent une action de votre part.** Deux points
arrêtent le build tant que vous n'y avez pas touché, et deux autres changent le vol.

### 1. Le bloc `settings:` de CTLD n'est plus lu — et `validate` le refuse

```yaml
modules:
  CTLD:
    enabled: true
    settings:            # ← n'existe plus
      hoverPickup: true
```

devient simplement :

```yaml
modules:
  CTLD: true
```

…et vos réglages partent dans un fichier `ctld-config.yaml`, à côté de `mission.yaml`. La
marche à suivre est en fin de page.

Pourquoi une erreur plutôt qu'un avertissement ? Parce que **ce canal n'a jamais complètement
fonctionné** : les valeurs écrites là étaient posées, puis écrasées par la configuration VEAF
en dur, sans un mot. Un `slingLoad: false` dans un `mission.yaml` n'a jamais rien fait. Plutôt
que de continuer en silence, l'outil s'arrête et vous dit où aller.

### 2. Les noms de zones réservés disparaissent

Les vingt noms `logistic #001` … `#020` et `pickzone #001` … `#020` ne sont plus reconnus.
CTLD 2 découvre ses zones **par préfixe de nom**, directement dans l'éditeur de mission :
`LGZ_` pour une zone logistique, `TRZ_` pour une zone d'embarquement de troupes. Sans limite de
nombre, et avec un nom qui dit ce que la zone fait.

Pour qu'une zone suive un objet mobile — un porte-avions —, liez-la à l'unité dans l'éditeur
(*Moving Zone*) : elle le suivra en vol.

### 3. Le ramassage des caisses change pour les pilotes

Jusqu'ici VEAF imposait l'**élingage réel** de DCS. Les outils reprennent désormais le
comportement par défaut de CTLD : **le stationnaire au-dessus de la caisse suffit**. Plus
permissif, et la fenêtre de stationnaire est un peu plus serrée :

| | Avant (VEAF) | Maintenant (CTLD 2) |
|---|---|---|
| hauteur de stationnaire | 5 à 15 m | 7,5 à 12 m |
| distance à la caisse | 8 m | 5,5 m |

### 4. Les capacités d'emport sont réalignées

Les limites que VEAF portait en dur dataient de la configuration d'origine. On adopte celles de
CTLD 2, calées sur les appareils :

| Appareil | Avant | Maintenant |
|---|---|---|
| UH-1H | 10 soldats | 8 |
| UH-60L | 20 | 12 |
| Mi-8MTV2 | 20 | 16 |
| CH-47F | 33 | 40 |

Les **Gazelle** (SA342 L/M/Mistral/Minigun) et le **Yak-52** gardent leur soldat unique et
n'emportent pas de caisse. Le **Ka-50** conserve son menu CTLD — reconnaissance, statut JTAC,
balises — mais ne transporte plus troupes ni caisses : l'ancienne version le lui permettait par
accident, pas par choix.

---

## 🛠️ Configurer CTLD : un outil, plus de YAML à la main

La configuration de CTLD est désormais un fichier **`ctld-config.yaml`** posé à côté de votre
`mission.yaml`, et vous l'éditez avec **`ctld-tools.exe`**, livré avec CTLD
([page des releases](https://github.com/VEAF/CTLD/releases)) : double-cliquez, il s'ouvre dans
votre navigateur, en local, sans rien installer.

Tout y est éditable — caisses, groupes de troupes, zones, capacités par appareil, zones IA —
avec des libellés en clair plutôt que des noms de réglages, les unités (m / kg / s), une
recherche sur l'ensemble des paramètres, un marqueur sur ce que vous avez changé et un retour
au défaut d'un clic. L'interface est en français. La validation tourne en continu et vous parle
de vos données, pas de la syntaxe.

`veaf-tools prepare` crée le fichier pour vous quand le modèle choisi active CTLD, prérempli
avec les valeurs par défaut du moteur et les choix VEAF (les porte-avions et les dépôts FARP
sont reconnus automatiquement comme points logistiques, comme avant). Ensuite il est à vous :
le build ne le réécrit jamais.

> **N'utilisez pas le bouton « Injecter dans la mission » de `ctld-tools`** sur une mission
> VEAF. Il écrit directement dans un `.miz`, or le `.miz` est reconstruit à chaque build depuis
> votre dossier mission : votre injection disparaîtrait au build suivant. Enregistrez le
> fichier, le build s'occupe du reste.

**Un point à connaître** : ce fichier est une configuration **complète**, pas une liste de
différences. Un réglage simple que vous omettez reprend la valeur par défaut du moteur — et
CTLD vous le dit à l'écran au démarrage de la mission. Mais une **liste** omise — une section
de caisses, un groupe de troupes, une zone — est réellement supprimée. C'est ainsi qu'on retire
un élément, et c'est pourquoi il vaut mieux partir du fichier existant que d'en écrire un.

Quand vous monterez CTLD de version, l'outil comparera votre fichier au nouveau catalogue et
vous listera ce qui est apparu, ce qui a disparu et ce qui diffère, avant que vous ne
réenregistriez. Rien n'est jamais fusionné dans votre dos.

---

## 📖 Documentation

- **Le guide du mission maker enseigne le nouveau modèle** : configuration en fichier dédié,
  zones par préfixe, ordre de chargement réel des scripts dans la mission, et un tableau
  avant/après pour la migration. En français et en anglais, comme le reste du site.
- **La documentation d'une version peut être republiée sans déplacer son tag.** Jusqu'ici, un
  correctif de documentation arrivé après la pose du tag ne pouvait pas atteindre les pages
  publiées : reconstruire depuis le tag rebâtissait l'ancien contenu.
- **Le tampon de version marque aussi le pied de page.** La page de référence Lua porte sa
  version à deux endroits et un seul était mis à jour : la page 6.12.0 annonçait encore
  « v6.5.25 — juin 2026 » en bas.

---

## 🔄 Migration, pas à pas

Pour chaque mission qui active CTLD :

1. **Récupérez `ctld-tools.exe`** sur la [page des releases de CTLD](https://github.com/VEAF/CTLD/releases).
2. **Lancez-le** (double-clic) et enregistrez la configuration dans votre dossier mission sous
   le nom `ctld-config.yaml`. Il démarre sur les valeurs par défaut : reportez-y les réglages
   que vous aviez dans `settings:`, s'il y en avait de réellement actifs.
3. **Dans `mission.yaml`**, remplacez le bloc `CTLD:` par `CTLD: true`.
4. **Dans l'éditeur de mission**, remplacez les unités et zones nommées `logistic #0NN` /
   `pickzone #0NN` par des zones nommées `LGZ_…` / `TRZ_…`.
5. **Dans `mission-script.lua`**, supprimez tout appel à `ctld.initialize(...)` : le framework
   VEAF s'en charge. Les fonctions `veaf.ctld_initialize_replacement` et `veaf.ctld_initialized`
   n'existent plus.
6. **Rebuildez** et lancez `veaf-tools validate` : il vous dira ce qui reste à corriger.

Les missions **Foothold** ne sont pas concernées : elles embarquent leur propre CTLD et le CTLD
VEAF y reste désactivé, comme avant.

---

## 🙏 Crédits

CTLD 2 est l'œuvre de **FullGas**, développeur principal de la réécriture — architecture,
moteur, outil de configuration. **Zip** a assuré l'intégration dans les outils de création de
mission.

Merci également aux mission makers qui remontent ce qui casse : c'est ainsi que les pièges
silencieux, comme un `settings:` que personne ne lisait, finissent par être trouvés.
