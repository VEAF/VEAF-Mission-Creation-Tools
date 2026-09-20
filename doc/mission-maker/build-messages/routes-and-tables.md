# Routes et tables

Deux petites familles qui partagent une propriété : elles parlent de données que **DCS lui-même**
refuse ou digère mal. Vous n'avez donc aucun moyen de deviner la règle depuis l'éditeur — elle ne
s'exprime nulle part dans l'interface.

## Aucun waypoint n'a d'heure verrouillée {#validate-route-no-locked-time}

> groupe « Patrouille-Nord » : aucun waypoint n'a de temps verrouillé — l'éditeur de mission DCS
> refuse d'enregistrer cette route. Verrouillez l'heure d'arrivée du premier waypoint.

**Dans l'éditeur.** Chaque waypoint d'une route porte deux cases à cocher qui nous intéressent :
l'**heure d'arrivée verrouillée** (l'ETA) et la **vitesse verrouillée**. L'éditeur DCS exige qu'au
moins un waypoint de la route ait son heure verrouillée. Sans ça, il affiche un encadré rouge et
refuse d'enregistrer la mission :

> *Route has no waypoints with locked time!*

**L'issue.** Verrouiller l'heure d'arrivée du **premier** waypoint. C'est le choix le plus sûr :
il fixe le départ, et laisse la suite se calculer.

**Ce que ce n'est pas.** Ce n'est pas VMCT qui a écrit ça. Ces routes arrivent telles quelles dans
votre mission — d'un copier-coller de waypoint, d'un modèle réutilisé, ou d'un outil tiers. Le
message est un avertissement, pas une erreur, précisément parce que DCS a déjà accepté ce fichier :
refuser de le construire serait pire que de vous le dire.

## Une vitesse verrouillée coincée entre deux heures {#validate-route-contradictory-locks}

> groupe « Patrouille-Nord » : le waypoint 2 a une vitesse verrouillée entre des waypoints à temps
> verrouillé — l'éditeur de mission DCS refuse d'enregistrer cette route. Retirez ETA_locked sur
> les waypoints après le premier, ou speed_locked sur celui-ci.

**Dans l'éditeur.** La contradiction est simple à énoncer : vous demandez à la fois d'arriver à une
heure précise et de voler à une vitesse précise, sur le même segment. DCS ne peut pas satisfaire
les deux, et le dit — en nommant la **route**, pas la case à cocher, ce qui rend le message d'origine
difficile à relier à quoi que ce soit :

> *All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!*

**Les deux issues, et ce qu'elles coûtent :**

| Issue | Effet |
|---|---|
| Décocher l'heure verrouillée sur les waypoints **après le premier** | La route part à l'heure, la suite s'enchaîne librement |
| Décocher la vitesse verrouillée sur le waypoint incriminé | La vitesse s'ajuste pour tenir les horaires |

**Comment on l'a trouvé.** Le 2026-08-22, `validate` a déclaré une mission saine quelques secondes
avant que l'éditeur DCS refuse de l'ouvrir. Le défaut venait d'un waypoint recopié à la main, pas
d'un outil — mais le vrai problème était le **silence** : une mission qui ne s'ouvre pas coûte une
session, et l'outil dont c'est le métier de le dire disait que tout allait bien.

**Ce que ce n'est pas.** Pas une histoire de carburant, de vitesse irréaliste ou de distance : la
contradiction est formelle, et elle se produit même sur une route parfaitement volable.

## Une table de mission est trouée {#validate-holed-sequence}

> La table de mission « coalition.blue.country[1].plane.group » est numérotée 1, 3, 4 au lieu de
> 1..3 — une retouche à la main ou un outil tiers y a laissé un trou. Le build le referme, mais
> mieux vaut vérifier que c'est bien ce que vous vouliez.

Au build, la même chose s'annonce plus brièvement :

> table de mission renumérotée : coalition.blue.country[1].plane.group

**Ce que ça veut dire.** Les tables Lua de DCS sont des listes numérotées `1, 2, 3…` sans trou.
Supprimer une entrée à la main laisse `1, 3, 4` : Lua charge le fichier sans broncher, mais tout
lecteur qui parcourt la liste s'arrête au trou — ou meurt dessus.

**D'où ça vient.** Une édition à la main de `src/mission/mission`, ou un outil tiers qui a retiré
un groupe sans renuméroter.

**Ce que le build en fait.** Il referme le trou tout seul, et vous prévient plutôt que de le faire
en silence. Le faire en silence a déjà coûté cher : le 2026-08-18, trois trous ont fait échouer
trois sous-systèmes sans rapport entre eux, sous un message (`'int' object has no attribute 'get'`)
qui n'en nommait aucun.

**Ce qu'il faut vérifier.** Que l'entrée disparue l'a bien été volontairement. Le build renumérote,
il ne ressuscite rien : si vous avez supprimé un groupe par erreur, il ne reviendra pas.

**Ce que ce n'est pas.** Pas une corruption du `.miz`, et pas un blocage : la mission se construit.

## Des préréglages radio sans appareil joueur {#validate-presets-no-aircraft}

> presets.yaml est configuré mais la mission n'a aucun aéronef joueur auquel appliquer les
> préréglages radio.

**Dans l'éditeur.** Les préréglages radio s'appliquent aux appareils dont une unité est en
compétence **Client** ou **Player** — les places que des pilotes occupent. Votre mission n'en a
aucune, donc l'étape n'a rien à faire.

**Les issues.** Ouvrir des places joueur dans l'éditeur, ou couper l'étape dans `mission.yaml` :

```yaml
pipeline:
  presets: false
```

**Ce que ce n'est pas.** Pas une erreur de votre `presets.yaml`, dont le contenu n'a même pas été
examiné. Et pour une mission de serveur ou une bibliothèque de modèles, c'est une situation
parfaitement normale.

## Des waypoints sans groupe d'aéronefs {#validate-waypoints-no-aircraft}

> waypoints.yaml est configuré mais la mission n'a aucun groupe d'aéronefs où injecter des
> waypoints.

Le jumeau du précédent, avec un critère plus large : ici il suffit d'un **groupe** d'avions ou
d'hélicoptères, joueur ou IA. N'en avoir aucun veut dire que la mission n'a rien qui vole.

**Les issues.** Les mêmes : poser des groupes aériens, ou couper `pipeline.waypoints`.

## Pour aller plus loin {#more}

- [Les messages du build](README.md) — les autres familles
- [Préréglages radio](../concepts/radio-presets.md)
- [Le build — les étapes du pipeline](../concepts/build.md#pipeline-steps)
