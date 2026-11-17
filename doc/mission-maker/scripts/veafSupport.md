# veafSupport — AWACS et ravitailleurs hors de portée

**ID du module :** `SUPPORT` | **Fichier :** `veafSupport.lua`

## À quoi il sert {#purpose}

Il tient les AWACS et les ravitailleurs d'une mission hors des défenses antiaériennes ennemies, tout seul : chaque moyen se replie quand une menace atteint son orbite, revient quand la voie est libre depuis longtemps, et dit à son camp où il se trouve.
Il marche dans n'importe quelle mission ; une [campagne persistante](../PERSISTENT_CAMPAIGN.md#support) le règle et lui donne la portée mesurée sur ses zones.

## L'activer {#enable}

Dans `mission.yaml` :

```yaml
modules:
  SUPPORT:
    enabled: true
    assets: [ "AWACS Magic", "Tanker Texaco", "Tanker Arco" ]
    margin: 30000
```

Chaque moyen est un groupe posé dans l'éditeur, avec une **orbite** dans sa route (les tâches AWACS et ravitailleur de l'éditeur) : c'est là qu'il se tient tant que rien ne le menace.
`MOVE` vient avec lui : l'orbite est déplacée par le déplacement de ravitailleur de `veafMove`.

## Comment un moyen se tient {#behaviour}

- **Où** : sur la ligne qui va de la menace la plus proche de son orbite de l'éditeur à cette orbite, au premier point hors de portée de **toutes** les menaces plus `margin`. Jamais plus près de la menace que son orbite — en campagne persistante, que la zone de son camp la plus avancée —, et aussi loin en arrière qu'il le faut.
- **Il se replie aussitôt** : quand une menace atteint son orbite (plus `margin`), il recule avec `retreat_margin`, plus large, pour ne pas rester au bord.
- **Il n'avance qu'après un long calme** : il se rapproche seulement quand une orbite plus proche de `min_advance` (30 km) est restée possible pendant `advance_seconds` (30 minutes), et pas avant `advance_seconds` après son dernier déplacement. Un SAM qui se réveille et se rendort, ou apparaît et meurt, toutes les quelques minutes ne le fait pas faire d'allers-retours : il recule une fois, et tient.
- **Chaque déplacement est annoncé** à son camp : la nouvelle orbite en relèvement et distance du bullseye, fréquence inchangée. En campagne, c'est le commandement de son camp qui parle.
- **Ses marques le suivent** : sa branche et une étiquette avec son nom et sa fréquence, dessinées sur la carte F10 pour son seul camp, effacées et redessinées à chaque déplacement, si bien que la carte et l'annonce disent toujours la même chose.
- **Un moyen réapparu** (menu des assets, boutique de la campagne) revient sur son orbite de l'éditeur : il est réévalué depuis là.

## Les menaces {#threats}

- **Dans une mission seule** : les unités au sol ennemies qui portent un missile sol-air d'une portée de `sam_reach_floor` (15 km) ou plus — la portée que DCS donne au missile, lue tant que l'unité est dans le monde. Les canons et les missiles de courte portée ne menacent pas un AWACS.
- **En campagne persistante** : chaque zone ennemie avec une garnison, à la portée mesurée sur ses missiles quand elle est éveillée et retenue quand elle dort, si bien qu'une zone qui s'endort garde sa menace.

## Réglages {#settings}

| Clé | Par défaut | Ce qu'elle règle |
|---|---|---|
| `assets` | aucun | les groupes tenus, par leur nom |
| `margin` | 30000 | mètres au-delà de toute portée ennemie où se tient l'orbite |
| `retreat_margin` | 50000 | mètres au-delà de la portée, quand il se replie |
| `seconds` | 60 | fréquence de réévaluation des menaces |
| `advance_seconds` | 1800 | combien de temps la voie doit rester libre avant qu'il se rapproche, et entre deux avancées |
| `min_advance` | 30000 | mètres dont une orbite doit être plus proche pour valoir une avancée |
| `leg` | 30 | nautiques de l'hippodrome, posé en travers de l'axe |
| `sam_reach_floor` | 15000 | mètres : dans une mission seule, un missile qui porte moins loin n'est pas une menace |

## Ce qui reste à vérifier en jeu {#to-verify}

L'orbite déplacée par le déplacement de ravitailleur de `veafMove`, sa branche en travers de l'axe, et les marques redessinées : écrits et testés hors de DCS.
