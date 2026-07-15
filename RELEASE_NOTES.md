# VEAF Mission Creation Tools — 6.9.2

Version ciblée : le **confort des menus radio F10**. Deux irritants disparaissent —
les menus trop longs ne sont plus tronqués par DCS, et les combat zones peuvent
enfin être **rangées** proprement dans le menu radio. Sur un **retour de Reaper**.

## 📻 Fini les menus radio tronqués (pagination automatique)

DCS n'affiche que **10 entrées** par menu radio : au-delà, le reste était
silencieusement **coupé**. Désormais, tout menu VEAF qui dépasse cette limite se
**pagine tout seul** — les entrées en trop passent dans un sous-menu **« Page
suivante »**, autant de fois que nécessaire.

- **Rien à configurer** : ça s'applique à tous les menus radio VEAF.
- **Pas de gaspillage** : un menu qui tient en 10 entrées n'affiche **pas** de
  « Page suivante ».
- Le menu **Combat Zones** en profite directement : une mission à 20 zones n'en
  masque plus la moitié.

## 🗂️ Ranger les combat zones dans le menu radio

Deux nouvelles clés optionnelles par zone dans `mission.yaml` :

```yaml
modules:
  COMBATZONE:
    combat_zones:
      - zone_name: "CZ-Alpha"
        friendly_name: "Alpha"
        radio_group_name: "Nord"     # regroupe les zones de même nom sous un sous-menu commun
        radio_menu_prefix: "BLEU"     # préfixe affiché devant le libellé de la zone
```

- `radio_group_name` : toutes les zones portant le **même nom** sont réunies sous un
  **sous-menu** de ce nom. Absent → la zone reste à la racine du menu Combat Zones.
- `radio_menu_prefix` : ajoute un **préfixe** au libellé de la zone (ex. `BLEU * Alpha`).

Ces réglages sont **repris automatiquement par `convert-v5`** : une mission v5 qui
groupait déjà ses zones les retrouve à l'identique en v6.

## ⚠️ À vérifier

- **Mission makers** : changement transparent, aucune reconfiguration nécessaire.
  Vos menus existants s'affichent comme avant (et ne se tronquent plus).
- **Développeurs de scripts** : si vous utilisiez `veafRadio.addPaginatedRadioElements`
  / `addPaginatedRadioMenu`, sachez qu'ils ne paginent **plus eux-mêmes** (le rendu
  s'en charge désormais pour tous les menus) — le résultat final est identique, les
  appels existants restent valides. Besoin de désactiver la pagination sur un menu
  précis : `veafRadio.doNotPaginate(monMenu)`.

## 🙏 Remerciements

Merci à **Reaper** d'avoir remonté ces besoins.
