# VEAF Mission Creation Tools — 6.9.1

Version ciblée : les **mods tiers ne bloquent plus le chargement d'une mission**.
Si votre mission utilise un avion tiers (payant ou communautaire), un pilote qui
ne le possède **pas** peut malgré tout **charger et jouer** la mission — le slot
concerné lui est simplement indisponible, au lieu de bloquer tout le monde à
l'écran de chargement. C'est le retour dans l'outillage v6 d'un comportement que
beaucoup connaissaient en v5. Sur un **retour de Reaper**.

## ✈️ Les mods tiers ne bloquent plus la mission

Auparavant (en v6), si un seul appareil tiers était présent dans la mission, DCS
**refusait de la charger** à quiconque ne possédait pas le mod correspondant.
Désormais, au build, VEAF **lève cette contrainte** pour une liste de mods tiers
courants — la mission s'ouvre pour tout le monde.

**Liste par défaut** (prise en charge automatiquement, rien à configurer) :
Hercules (C-130), UH-60L, A-4E-C, T-45, AM2, SU-30 (FlankerEx), Bronco OV-10A.

**Vous utilisez un autre avion tiers ?** Ajoutez-le dans `mission.yaml` :

```yaml
mission:
  third_party_mods: [MonAvionTiers]
```

Votre liste s'**ajoute** à celle de VEAF (elle ne la remplace pas). Au build, VEAF
indique quels mods ont été rendus non bloquants.

📖 Doc : [Référence mission.yaml — `third_party_mods`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/MISSION_YAML_REFERENCE.md)

## ⚠️ À vérifier (mission makers)

- Changement **purement additif** : les missions existantes ne perdent rien, aucune
  reconfiguration nécessaire.
- La levée de contrainte est **automatique** pour les 7 mods de la liste par défaut.
  Si (cas très rare) vous vouliez au contraire **imposer** la possession d'un de ces
  mods, ce n'est plus le comportement par défaut.
- Les avions eux-mêmes restent dans la mission : seul le **verrou de chargement** est
  retiré.

## 🙏 Remerciements

Merci à **Reaper** d'avoir remonté ce besoin.
