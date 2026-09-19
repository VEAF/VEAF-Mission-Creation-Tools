# Modules et scripts communautaires

La famille où l'on se demande le plus souvent « est-ce que j'ai cassé quelque chose ? ». Souvent,
non — et c'est même une des raisons d'être de cette page.

## Le fait qui explique presque tout {#community-opt-out}

**Les scripts communautaires sont activés par défaut.** Vous n'avez rien à écrire dans
`mission.yaml` pour que CTLD, CSAR ou MiST soient candidats à l'embarquement : ils sont là sauf si
vous les retirez.

C'est confortable, mais ça a un effet de bord désagréable : un avertissement peut vous parler d'un
module que vous n'avez **jamais** demandé, et le message se lit alors comme une accusation. Pour
sortir un module :

```yaml
modules:
  CTLD: false
```

## CTLD est activé, mais sans configuration {#builder-ctld-no-config}

> CTLD est activé mais aucun ctld-config.yaml n'a été trouvé dans le dossier mission — CTLD
> utilisera ses valeurs par défaut. Créez-en un avec ctld-tools.exe, à télécharger depuis
> https://github.com/VEAF/CTLD/releases (les releases de CTLD 2 sont des pre-releases : passez par
> l'onglet Releases).

**Quand il apparaît.** Vous avez **explicitement** écrit CTLD dans `modules:` de votre
`mission.yaml`, et il n'y a pas de `ctld-config.yaml` dans le dossier de mission.

**Ce que ça change.** CTLD tourne avec ses réglages d'origine : les types d'unités logistiques, les
zones de troupes, les points de largage sont ceux du script, pas les vôtres.

**L'issue.** Créer le fichier avec `ctld-tools.exe`. Le lien du message est le bon endroit — et la
précision sur les pre-releases est importante : les versions de CTLD 2 n'apparaissent pas dans la
liste principale des releases GitHub.

**Ce que ce n'est pas.** Pas une erreur, et CTLD fonctionne. Si ses réglages par défaut vous vont,
vous pouvez ignorer ce message indéfiniment.

## CTLD est là parce qu'il est là {#builder-ctld-no-config-by-default}

> CTLD est dans cette mission parce que les scripts communautaires sont activés par défaut — votre
> mission.yaml ne le mentionne nulle part. Il n'y a pas de ctld-config.yaml ici, donc CTLD tourne
> simplement avec ses propres réglages : rien n'est cassé, vous pouvez ignorer ce message. Pour
> retirer CTLD de la mission, ajoutez 'CTLD: false' sous 'modules:' dans mission.yaml. Pour le
> configurer au contraire, créez ctld-config.yaml avec ctld-tools.

**Rien n'est cassé.** Ce message existe parce que le précédent, affiché dans cette situation-là,
disait en substance « allez télécharger un outil » à quelqu'un qui n'avait jamais entendu parler de
CTLD. Il a été séparé exprès.

**La différence avec le message précédent**, et c'est toute la subtilité :

| | Vous avez écrit `CTLD` dans `modules:` | Vous n'avez rien écrit |
|---|---|---|
| Message | « CTLD est activé mais aucun fichier… » | « CTLD est dans cette mission parce que… » |
| Ce qu'on vous propose | Créer la configuration | Retirer CTLD, **ou** le configurer |

**Les issues.** Ne rien faire, ou écrire `CTLD: false` sous `modules:` si vous ne voulez pas de
CTLD dans votre mission.

## CTLD sans aucun point logistique {#builder-ctld-logistics-unmanaged-and-empty}

> ════════════════════════════════════════════════════════════════
> ATTENTION — CTLD : AUCUN POINT LOGISTIQUE
> modules.CTLD.manage_logistics est à false et, dans ctld-config.yaml, logisticUnitTypes et
> troopZoneShipTypes sont vides.
> Aucune FARP ni aucun porte-avions placé dans l'éditeur ne sera un point de chargement.
> Si ce n'est pas voulu, repassez manage_logistics à true, ou renseignez ces listes avec ctld-tools.
> ════════════════════════════════════════════════════════════════

**Dans l'éditeur.** Vos FARP et vos porte-avions sont bien là, visibles, posés — et aucun ne sera
un point de chargement CTLD. Les hélicoptères ne pourront ni embarquer des troupes ni prendre de
cargaison nulle part.

**Pourquoi c'est encadré.** C'est une combinaison légitime — on peut vouloir gérer sa logistique
entièrement à la main — mais jamais un accident sur lequel se taire. D'où l'encadré : c'est la
seule manière de ne pas le rater dans une sortie de build.

**Les issues.** Remettre `manage_logistics: true` pour que VMCT complète les listes, ou les
renseigner vous-même avec `ctld-tools`.

## CTLD : les types logistiques ont été complétés {#builder-ctld-logistics-merged}

> CTLD : gestion automatique de la logistique — logisticUnitTypes complété avec FARP, … Votre
> ctld-config.yaml n'est pas modifié ; c'est la copie injectée dans la mission qui l'est.

**Tout va bien.** Le message a une deuxième phrase pour une bonne raison : votre fichier sur le
disque **n'est pas touché**. Ce qui change, c'est la copie remise au moteur. Sans cette précision,
vous liriez une chose dans `ctld-tools` pendant qu'une autre tourne en jeu.

**Pour l'arrêter.** `manage_logistics: false` sous `modules.CTLD` — mais relisez le message
précédent avant, c'est exactement le chemin qui y mène.

## Des fichiers son manquent {#builder-community-sounds-missing}

> Des fichiers son requis par un module communautaire activé ne sont fournis ni par les outils ni
> par la mission : beacon.ogg. Ajoutez-les dans src/mission/l10n/DEFAULT/ sinon la fonctionnalité
> associée sera muette (ex. beacons CTLD).

**Ce que ça veut dire.** Un module activé appelle un son que ni les outils ni votre dossier ne
fournissent. En jeu, la fonctionnalité marchera — silencieusement.

**Où le fichier doit aller.** Dans `src/mission/l10n/DEFAULT/`, et **nulle part ailleurs**. Un son
posé ailleurs dans la mission (dans le dossier des planchettes, par exemple) ne compte pas : les
scripts le cherchent à cet endroit précis.

**Les issues.** Ajouter le fichier, ou désactiver le module qui le réclame.

## TUM sans zones de territoire {#validate-tum-zones-missing}

> TUM est activé mais aucune zone de territoire BLUFOR, REDFOR n'a été trouvée —
> TheUniversalMission s'arrête au démarrage sans elles.

**Dans l'éditeur.** TUM a besoin d'au moins une zone de déclenchement dont le nom **commence par**
`BLUFOR` et d'une dont le nom commence par `REDFOR` — la casse n'a pas d'importance. Ce sont les
territoires de départ des deux camps.

**Ce qui se passe sans elles.** TUM s'arrête à l'initialisation. Pas de message en jeu, pas de
menu : le module est simplement absent. Cet avertissement de build est donc la seule notification
que vous aurez.

**Les issues.** Créer les zones dans l'éditeur, ou désactiver TUM dans `mission.yaml`.

## Un module est incompatible avec le profil de conversion {#validate-incompatible-module}

> modules : « CTLD » est incompatible avec le profil de conversion « foothold » et doit rester
> désactivé.

Au build, c'est un refus pur et simple :

> Build impossible : le(s) module(s) CTLD sont incompatibles avec le profil de conversion
> « foothold ». Désactivez-les dans mission.yaml.

**Ce que ça veut dire.** Votre `mission.yaml` porte un `conversion_profile`, et ce profil déclare
certains modules VEAF incompatibles. Pour `foothold`, c'est **CTLD** : une mission Foothold embarque
son propre CTLD dans ses `custom_scripts`, et charger les deux ensemble les fait entrer en conflit.

**L'issue, unique.** Désactiver le module :

```yaml
modules:
  CTLD: false
```

**Ce que ce n'est pas.** Pas une opinion sur la qualité du module — c'est une question de
double-chargement. Et c'est un des rares messages de cette documentation qui **arrête** vraiment le
build.

## Un module toujours actif ne peut pas être désactivé {#builder-mandatory-module-enable}

> Le module 'UNITS' est toujours actif et ne peut pas être activé ou désactivé (enable: false) —
> supprimez la clé 'enable' de son entrée dans mission.yaml.

**Celui-ci arrête le build.** C'est une erreur, pas un avertissement : le `.miz` n'est pas écrit.

**Les modules concernés.** `UNITS`, `TIME`, `CACHE`, `EVENTS`, `MARKERS` et `COMMANDS`. Ce sont les
fondations du framework VEAF : tout le reste en dépend, alors les activer ou les désactiver n'a pas
de sens.

**Ce qui le déclenche exactement.** Uniquement la forme développée, avec une clé `enable` ou
`enabled` à l'intérieur :

```yaml
modules:
  UNITS:
    enable: false      # ← refusé
```

**L'issue.** Retirer cette clé. Vous pouvez garder l'entrée pour **configurer** le module ; c'est
seulement le fait de prétendre l'allumer ou l'éteindre qui est refusé.

## Un id de script communautaire est inconnu {#builder-unknown-community-script}

> ID de script communautaire inconnu 'ctdl' dans 'community_scripts:' ; ignoré.

**Presque toujours une faute de frappe**, ou le nom d'un script retiré des outils depuis. L'entrée
est ignorée — donc si vous cherchiez à **désactiver** ce script, sachez que ça n'a rien désactivé
du tout.

**Au passage :** `community_scripts:` est la forme dépréciée. Voir ci-dessous.

## `lua_modules:` et `community_scripts:` sont dépréciés {#builder-modules-deprecated}

> Déprécié : 'lua_modules:' et 'community_scripts:' sont remplacés par 'modules:' — merci de mettre
> à jour votre mission.yaml

Et si vous avez les deux formes à la fois :

> 'modules:' et 'lua_modules:'/'community_scripts:' sont tous deux présents — 'modules:' a la
> priorité

**Ce que ça veut dire.** Les anciennes sections marchent encore, mais `modules:` les remplace toutes
les deux : un seul bloc pour les modules VEAF et les scripts communautaires.

**Le piège quand les deux coexistent.** `modules:` gagne, **entièrement**. Un module que vous
croyez activé dans `lua_modules:` ne l'est pas s'il n'est pas dans `modules:` — c'est la cause la
plus vicieuse d'un module qui « ne démarre pas » sans qu'aucun message ne le dise.

**L'issue.** Fusionner dans `modules:`, puis supprimer les deux anciennes sections. Voir
[`mission.yaml` et ses modules](../concepts/mission-yaml.md).

## Pour aller plus loin {#more}

- [Les messages du build](README.md) — les autres familles
- [`mission.yaml` et ses modules](../concepts/mission-yaml.md)
- [Référence `mission.yaml` — `modules:`](../../MISSION_YAML_REFERENCE.md#modules)
