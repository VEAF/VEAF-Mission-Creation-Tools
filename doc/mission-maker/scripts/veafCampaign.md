# veafCampaign — Campagne multi-missions

**Module ID:** `CAMPAIGN` | **Fichier:** `veafCampaign.lua`

---

## Objectif

Fait tourner **une mission** d'une campagne jouée mission après mission : il fait apparaître les garnisons de la campagne moins leurs pertes, montre la situation sur la carte F10 et dans un menu radio, gère la prise des zones neutres par présence au sol, et écrit le fichier d'état que la mission suivante reprendra.

La campagne elle-même — sa déclaration, son état, le passage d'une mission à l'autre — se mène avec les commandes `veaf-tools campaign` : voir [Campagne multi-missions](../CAMPAIGN.md).

---

## Activation

Le module ne se configure pas à la main : `veaf-tools campaign next` l'active dans `mission.yaml` et écrit ses données dans `src/campaign-data.yaml`.

```yaml
modules:
  CAMPAIGN:
    enable: true
    data_file: src/campaign-data.yaml
```

Au build, le contenu de `data_file` devient la table `veafCampaign.data`, posée juste avant `veafCampaign.initialize()`.
Sans données (le fichier manque), le module le dit dans `dcs.log` et ne fait rien.

---

## Ce qu'il fait en jeu

| quand | quoi |
|---|---|
| au démarrage | chaque aérodrome de la campagne passe à son propriétaire, la capture automatique de DCS coupée ; les garnisons jamais tirées le sont ; toutes apparaissent moins leurs pertes |
| toutes les 10 s | les zones neutres sont examinées pour la capture ; la carte est redessinée là où quelque chose a changé |
| toutes les `state_write_seconds` | le fichier d'état est écrit |
| à la perte d'une unité de garnison | la perte est enregistrée ; une zone sans garnison devient neutre |
| à la fin de la mission | le fichier d'état est écrit une dernière fois |

Une seule boucle pour tout le module, aucun minuteur par zone.

---

## Menu radio

**Campagne → Situation** : les zones avec leur propriétaire et la force de leur garnison, les captures en cours, les objectifs, le numéro de la mission.

**Campagne → Compteurs (admin)** : battements, zones visitées, dessins, unités apparues, pertes traitées, écritures d'état — de quoi vérifier que le module travaille.

---

## Fichier d'état

`<Saved Games>\DCS\Missions\Saves\<campagne>\mission-NN.state`, une table Lua (`return { … }`) que `veaf-tools campaign apply` relit.
Il demande `io` et `lfs` dans l'environnement des scripts de mission ; `os` est utilisé quand il est là, pas exigé.
Voir [le fichier d'état](../CAMPAIGN.md#state-file).
