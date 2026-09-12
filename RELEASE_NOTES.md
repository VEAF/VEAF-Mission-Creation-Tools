# VEAF Mission Creation Tools — 6.22.0

**Un objet statique qu'une zone de combat replace revient.** Il ne revenait pas toujours. Il
disparaissait à la première désactivation de la zone, définitivement, et rien ne le signalait à
l'écran — cinq sacs de sable sur huit dans la mission où le défaut a été trouvé.

Cette version corrige cela, et livre CTLD **2.0.0-rc8**, qui apporte le ramassage de troupes aux FOB
et aux FARP construits.

---

## ⚠️ À lire avant de mettre à jour

Rien ne change dans ce que vous écrivez : ni `mission.yaml`, ni vos scripts, ni vos zones. Mais
**deux comportements arrivent activés**, et il vaut mieux le savoir avant de builder.

### Le ramassage de troupes aux FARP est actif par défaut

CTLD rc8 ajoute le ramassage de troupes sur les trois FARP construits (standard, Alpha, Countryside),
avec un rayon de 150 m. Jusqu'ici les FARP n'en avaient aucun. Si vous ne le voulez pas dans votre
mission, désactivez `troopPickupAtFARP` dans l'outil de configuration CTLD.

### Si — et seulement si — vous activez TheUniversalMission

Le script communautaire TUM passe de la version 0.1 à la **0.3**. Il reste **désactivé par défaut** :
une mission qui ne l'active pas explicitement ne voit aucune différence. Si vous l'utilisez, sachez
que l'auteur ne publie pas de détail de ses changements — nous avons vérifié que la convention des
zones BLUFOR/REDFOR est inchangée, mais un essai avant de jouer sérieusement reste prudent.

---

## Les objets statiques d'une zone de combat

### Ils disparaissaient pour de bon

Un objet statique porte deux noms dans l'éditeur : celui du **groupe**, et celui de l'**unité** qu'il
contient. Ils sont identiques tant que vous ne dupliquez rien. Dès que vous copiez un statique,
l'éditeur nomme l'unité `<groupe>-1` — et c'est là que ça se jouait.

Une zone de combat retenait le nom de l'unité, puis cherchait un groupe portant ce nom au moment de
remettre l'objet en place. Elle ne le trouvait pas, donc ne le recréait pas. La destruction, elle,
fonctionnait parfaitement : l'objet partait à la désactivation de la zone et ne revenait jamais.

C'est corrigé, pour les deux façons de nommer. Rien à changer dans vos missions : les statiques déjà
placés reviennent, y compris ceux que vous aviez dupliqués.

Deux autres situations tombaient sur exactement le même défaut, et sont réparées avec :

- **un statique déplacé par script** n'emportait pas sa définition ;
- **un navire posé en objet statique** perdait sa vérification « peut être sur l'eau », et se voyait
  chercher une place sur la terre ferme.

### Ce que vous avez caché reste caché

L'éditeur écrit trois options ensemble quand vous masquez un groupe : sur la carte, sur les écrans
de bord, et dans le planificateur. L'outil n'en retenait qu'une. Tout ce qu'il replaçait revenait
donc visible sur les liaisons de données et dans le planificateur, même si vous l'aviez masqué
partout. Les trois voyagent maintenant ensemble, pour un clonage, un replacement et un statique.

> **Une question reste ouverte**, et elle est signalée ici parce qu'elle a été rapportée : sur un
> serveur distant, des unités marquées « cachées » apparaissent sur la carte F10. Nous avons vérifié
> que la mission construite est correcte et que l'outil transmet bien le réglage. Reste à établir si
> DCS lui-même respecte « caché » sur un objet recréé pendant la partie. En attendant, si vous
> constatez le symptôme, regardez les **options forcées** de votre mission : une vue de carte réglée
> sur « tout voir » s'impose à tous les clients qui rejoignent un serveur, et montre tout.

---

## CTLD 2.0.0-rc8

Aucun réglage n'a été renommé ni supprimé, et chaque valeur par défaut existante garde son
comportement.

- **Les troupes peuvent enfin être embarquées à un FOB construit.** Le réglage existait depuis la
  réécriture, activé par défaut — mais rien dans le menu F10 ne le consultait, donc un FOB n'offrait
  jamais l'embarquement, quel que soit son réglage.
- **Et à un FARP construit**, ce qui n'existait pas du tout. Les trois FARP intégrés enregistrent
  leur zone d'embarquement dès la fin de la construction, et la retirent quand DCS détruit le FARP.
- **Un quart de la bande FM était inaccessible.** Les plages 36–39.9, 46–49.9, 56–59.9 et 66–69.9 MHz
  étaient ignorées — y compris des fréquences ordinaires comme 38.00 MHz. Les 460 pas de 30.0 à
  75.9 MHz sont joignables.
- Pour les scripteurs : une balise posée par script peut être demandée **sur une fréquence précise**,
  et une zone d'embarquement de troupes peut être ajoutée **sur n'importe quel objet nommé** — unité,
  statique, groupe ou aérodrome — et plus seulement sur une zone de déclenchement.

---

## Merci

À **Tripack**, qui a rapporté le symptôme de la carte F10 et surtout joint sa mission et le journal
de son serveur : c'est dans ce journal qu'a été trouvé le défaut des statiques, qu'il n'avait pas vu
et qui lui coûtait des objets à chaque partie. Il est aussi le testeur de CTLD rc8.

À **Zip**, pour les deux défauts CTLD corrigés dans rc8.
