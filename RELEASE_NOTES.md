# VEAF Mission Creation Tools — 6.23.0

**Tout ce qui est corrigé ici a été signalé en vol.** Pas un audit, pas un nettoyage de fond : des
pilotes et des mission makers ont vu quelque chose d'anormal, l'ont remonté, et voilà les
correctifs. Le moteur CTLD passe de la **2.0.0-rc9** à la **2.0.0-rc11**, et l'outil de lecture des
logs redevient téléchargeable.

**Si vous avez une mission en service, reconstruisez-la avec cette version** : c'est tout ce qu'il y
a à faire.

---

## 🚁 CTLD — cinq correctifs, tous venus du terrain

### Le menu F10 déclenchait la mauvaise commande

Un C-130 posé sur une zone de ramassage demande « Load Standard Group »… et lâche un fumigène rouge.
Le menu CTLD se reconstruit entièrement à chaque rafraîchissement, et quand un rafraîchissement de
fond tombait pendant que vous naviguiez dans le menu, votre clic suivant tombait sur l'arborescence
reconstruite. Les rafraîchissements de fond attendent désormais que vous ayez fini.

### Une caisse HAWK ou Patriot restait indéfiniment dans « Unpack »

Après avoir assemblé un système HAWK, le menu continuait d'annoncer une caisse disponible. Cliquer
dessus échouait à chaque fois, sans jamais nettoyer l'entrée. Les caisses réellement consommées par
l'assemblage disparaissent maintenant, y compris celles dont le système n'a théoriquement pas besoin.

### Changer de slot ou de coalition laissait une erreur et un menu fantôme

Le symptôme visible était dans le `dcs.log` :

```
CTLDDCSEventBridge:onEvent handler error [onPlayerLeaveUnit / eventId=21]:
attempt to call method 'getName' (a nil value)
```

À chaque changement de slot ou de coalition. Derrière cette ligne, le nettoyage du joueur partant ne
se faisait pas : il restait enregistré et son menu CTLD n'était jamais démonté. Les appareils à
équipage multiple en souffraient le plus — leur menu n'était plus jamais démonté du tout.

### Un rafraîchissement annulé pouvait retomber sur le joueur suivant

DCS réutilise les identifiants de groupe. Un rafraîchissement de menu annulé au départ d'un joueur
pouvait encore se déclencher chez celui qui reprenait le même slot, dans sa première seconde de vol.

### Les pilotes non-transport retrouvent ce qui les concerne

La reconnaissance CTLD est utilisable par **n'importe quel pilote**, avion de chasse compris. Or un
pilote sans capacité de transport pouvait se retrouver sans aucun menu CTLD, donc sans reconnaissance.

Désormais son menu contient **RECON**, **Smoke**, **List Beacons**, **JTAC Status** et **FOBs List** ;
il n'a plus **Check Cargo**, qui ne pouvait de toute façon lui répondre que « rien à bord ».
Les commandes de transport — troupes, caisses, véhicules, pose de balises — restent réservées aux
appareils qui transportent.

**Un point d'attention si votre mission utilise `addPlayerAircraftByType: false`** pour réserver CTLD
à une liste de slots nommés : ces pilotes-là voient maintenant apparaître ce menu réduit. Le réglage
continue de faire ce pour quoi il existe — réserver le **transport** à votre liste — mais il ne masque
plus les fonctions qui n'ont rien à voir avec le transport. Si vous teniez à ne rien afficher du tout,
chaque fonction garde son propre interrupteur : `reconF10Menu`, `enableSmokeDrop`,
`enabledRadioBeaconDrop`, `JTAC_jtacStatusF10`.

Aucun autre réglage ne change, et votre `ctld-config.yaml` n'a pas besoin d'être retouché.

---

## 📥 `veaf-logs.exe` est de nouveau téléchargeable

L'outil de lecture des logs existe depuis la **6.18.0**, mais il n'était présent que sur les pages de
version, jamais sur la page « Latest » vers laquelle pointent tous les liens de téléchargement.
Autrement dit : disponible sur le papier, introuvable en pratique pendant quatre versions.

Il est là, et un contrôle automatique vérifie désormais **chaque** fichier publié, pour que le
prochain outil ajouté ne disparaisse pas de la même façon.

---

## Comment mettre à jour

1. Téléchargez `veaf-tools.exe` ci-dessous.
2. Reconstruisez vos missions.

Rien d'autre : pas de migration, pas de changement de configuration.
