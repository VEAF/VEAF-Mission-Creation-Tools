# VEAF Mission Creation Tools — 6.22.1

**Correctif urgent.** Une mission construite avec la **6.22.0** démarre, se joue… et n'a **aucun menu
radio F10**. Ni celui de CTLD, ni celui de VEAF. Rien d'autre ne le signale.

Si vous avez construit une mission avec la 6.22.0, **reconstruisez-la avec cette version** : c'est
tout ce qu'il y a à faire.

---

## ⚠️ Ce que vous avez peut-être déjà vu

- Vous lancez votre mission, tout a l'air normal, les avions et les unités sont là.
- Vous ouvrez le menu radio F10 : **aucune commande VEAF, aucune commande CTLD**. Comme si les
  scripts n'avaient jamais été chargés.
- Dans `dcs.log`, une seule ligne en parle, quelque part au milieu de milliers d'autres.

**Rien dans votre mission n'est en cause** : ni votre `mission.yaml`, ni vos scripts, ni vos zones,
ni votre configuration CTLD. Il n'y a rien à corriger de votre côté et rien à changer.

## Ce qui s'était passé

La 6.22.0 embarquait CTLD **2.0.0-rc8**, sorti quelques jours plus tôt. Ce CTLD-là ne démarrait pas :
il s'interrompait en cours de chargement, avant même d'avoir commencé à fonctionner.

Et comme les scripts d'une mission VEAF sont chargés les uns à la suite des autres, CTLD passant
avant le reste, son interruption emportait **tous les scripts VEAF avec elle**. D'où l'absence totale
de menu, et pas seulement celle de CTLD.

CTLD est actif sauf si vous l'avez désactivé — donc pratiquement toutes les missions construites avec
la 6.22.0 sont concernées.

Le problème a été signalé par **Tripack** quelques heures après la sortie, avec sa mission et son
journal à l'appui. Merci à lui : sans ça, le défaut serait resté en ligne tout le week-end.

## Ce que corrige la 6.22.1

Cette version embarque CTLD **2.0.0-rc9**, qui corrige le défaut à la source. Tout ce que la 6.22.0
apportait est toujours là — le ramassage de troupes aux FOB et aux FARP construits, les corrections
de fréquences de balises — cela n'avait simplement jamais eu l'occasion de fonctionner.

Rien d'autre ne change : aucun réglage renommé, aucun réglage supprimé, aucune valeur par défaut
modifiée depuis la 6.22.0.

## Et pour que cela ne se reproduise pas

Jusqu'ici, avant d'intégrer une nouvelle version d'un script communautaire, nous vérifiions qu'il
était **lisible** par DCS. Nous vérifions désormais qu'il **démarre vraiment** — ce qui est
précisément ce qui manquait ici. Le projet CTLD a ajouté la même vérification de son côté.

---

## Mise à jour

Téléchargez `veaf-tools.exe` ci-dessous, remplacez votre exécutable, et reconstruisez vos missions.

Si vous préférez ne pas mettre à jour tout de suite : réinstaller CTLD dans votre `.miz` avec
`ctld-tools.exe` de la [version 2.0.0-rc9](https://github.com/VEAF/CTLD/releases/tag/published-v2.0.0-rc9)
règle le problème aussi.
