# VEAF Mission Creation Tools — 6.21.0

**Une batterie SAM qu'une zone de combat remet sur la carte voit, s'allume et tire.** Elle ne le
faisait plus. Elle avait l'air normale — présente, complète, munitions pleines — et elle laissait
passer les avions sans un mot, pendant que la console IADS annonçait des radars détruits que
personne n'avait touchés.

Cette version corrige cela, et six défauts voisins trouvés en tirant sur le même fil.

Elle apporte aussi la suite du bot de support : ses suivis ouvrent désormais un post dans le canal
forum du Discord, avec le tag que le forum exige.

---

## ⚠️ À lire avant de mettre à jour

Aucune rupture d'interface : rien de ce que vous écrivez dans `mission.yaml` ou dans vos scripts ne
change. Mais **deux comportements changent**, et une mission qui s'appuyait sur les anciens lira
autre chose.

### Le décompte des sites IADS baisse au lieu de gonfler

Un site dont le groupe **quitte la mission sans être détruit** — typiquement une zone de combat
qu'on désactive, qui emporte ses défenses avec elle — restait dans le réseau jusqu'à la fin de la
partie. Il gonflait la page de statut et son nom restait pris.

Il en sort maintenant. Si vous lisiez le nombre de sites SAM comme un total stable, il devient un
nombre qui suit ce qui est réellement sur la carte.

**Les sites que vos pilotes ont détruits, eux, restent affichés** : c'est le tableau de chasse, et
c'est la lecture d'une SEAD réussie. La distinction se fait sur ce que DCS rapporte — un site tombé
sous les coups est signalé, un site retiré par un script ne l'est pas.

### Les défenses d'une zone de combat rejoignent l'IADS sans `dynamic_spawn`

Une défense antiaérienne qu'une zone de combat replace rejoint le réseau de sa coalition **quel que
soit** ce réglage. Le contenu qu'un auteur a placé dans une zone n'est pas une apparition que
personne n'a demandée.

Auparavant l'appartenance au réseau se jouait sur un hasard d'ordonnancement : l'activation d'une
zone et l'enrôlement de démarrage sont programmés à la même seconde, donc une batterie entrait dans
le réseau si l'activation passait la première — et n'y revenait jamais après un cycle de la zone.

Seuls les éléments qui **restent en place** sont concernés : un convoi qui traverse la zone n'a rien
à faire dans un réseau de défense aérienne.

---

## Les SAM des zones de combat

Sept correctifs, un même symptôme vu de sept endroits.

### Une batterie remise en place était aveugle

C'est la cause racine, et elle tient en un mot. Quand une zone de combat replace une batterie,
l'outil reconstruit le groupe à partir de ce qu'il a mémorisé de l'éditeur — et il le reconstruisait
en **mélangeant l'ordre des véhicules**.

Or DCS attend que le **radar soit le premier véhicule du groupe**. S'il ne l'est pas, le jeu crée la
batterie sans aucun capteur : pas seulement le radar, *tous* les véhicules. Le site ne voit donc
rien, ne s'allume jamais, ne tire jamais — et la console IADS l'affiche en « radar détruit »
puisqu'elle constate qu'aucun radar ne répond. Un seul défaut, deux symptômes qui n'avaient l'air
d'avoir aucun rapport.

Cela dépassait Skynet : tout ce qui s'appuyait sur « la première unité » d'un groupe replacé
s'appuyait en réalité sur une unité tirée au hasard.

### Le réseau enrôlait des groupes que DCS venait de détruire

Au démarrage, la console annonçait des sites au radar détruit alors que rien n'avait été tiré. DCS
continue de lister pendant un court instant les groupes qu'il vient de retirer, et l'enrôlement du
réseau arrive juste après le nettoyage que fait chaque zone de combat. Ces fantômes entraient dans
le réseau et y restaient.

Le journal nomme désormais chaque groupe fantôme écarté, sans que vous ayez à activer quoi que ce soit.

### Un radar sans portée est réinterrogé, et le journal le nomme

Si un site rapporte une portée de détection nulle, il est réinterrogé plusieurs fois plutôt que
laissé pour mort sur une seule lecture malheureuse. Et s'il reste muet, le journal nomme l'unité
radar concernée, son type, et ce que DCS en dit — de quoi diagnostiquer sans avoir à deviner.

### Le graphe de couverture est reconstruit quand un site part

Un site retiré du réseau restait listé comme couvert par tous ceux qui pouvaient le voir. Les radars
d'alerte annonçaient des sites qui n'existaient plus.

### Et le reste

Retirer un site ne rend plus muettes les défenses rapprochées qui le protégeaient — elles restaient
listées et commandées, mais sourdes aux événements du jeu. Une batterie replacée sous son propre nom
peut rejoindre le réseau au lieu d'être refusée. Et décrire un site dont l'objet DCS a disparu ne
provoque plus d'erreur.

---

## Le bot de support ouvre ses suivis dans le forum

Un `/bug` ou un `/suggest` créait un fil accroché à un message que le bot devait poster dans le canal
où vous aviez tapé la commande. C'est maintenant un **post dans le canal forum** dédié, avec son
titre, son état ouvert/fermé, et plus de message d'ancrage qui traîne. `/ask` reste dans le canal :
une question et sa réponse n'ont pas vocation à devenir un sujet de forum.

Le post porte le **tag** que le forum réclame — le forum du VEAF les exige, et Discord refuse un post
sans tag. Les tags sont reconnus par leur nom (`issue`, `suggestion` par défaut), parce que Discord
n'offre aucun moyen de copier l'identifiant d'un tag.

Et la réponse privée qui clôt votre commande vous donne le **lien du fil** : évident tant qu'il
pendait trois lignes plus bas, indispensable dès lors qu'il est ailleurs.

Deux corrections sur le suivi des tickets : fermer une issue ne vous **désabonnait** plus
définitivement de ses suites, et une issue supprimée cesse d'être interrogée au lieu de l'être
indéfiniment.

---

## Pour les développeurs

- L'index des groupes de mission conserve l'ordre des unités de l'éditeur. Tout ce qui reconstruit un
  groupe à partir de cet index le soumet désormais à DCS dans l'ordre où il a été dessiné.
- Le retrait d'un élément d'un réseau IADS détache d'abord ses défenses rapprochées, reconstruit la
  couverture, et n'appelle plus le jeu sur un objet qu'il a libéré.
- Un site du réseau dont l'objet DCS a disparu se décrit sans lever d'erreur, ce qui rend les lignes
  de diagnostic utilisables là où elles servent.

---

*Merci à **Tripack** : il a rapporté le défaut, fourni son journal, puis construit une petite mission
de test qui reproduisait le problème à coup sûr, et essuyé trois versions successives. Sans cette
mission, la cause n'aurait pas été trouvée.*

*Quant à la validation finale, elle a consisté à aller narguer le SA-6 remis en état. Il a fallu
faire demi-tour pour rentrer dans son enveloppe, et il nous a descendus. On n'avait jamais été aussi
contents de mourir.*
