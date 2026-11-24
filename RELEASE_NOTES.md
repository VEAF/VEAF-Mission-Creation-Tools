# VEAF Mission Creation Tools — 6.39.1

**Une campagne persistante se monte avec l'assistant IA seul, et les menus radio gardent « Page suivante » à leur place.**

---

## 🤖 La campagne persistante avec l'assistant IA

- **Plus besoin de terminal ni du dépôt** : avec Claude Desktop et le serveur MCP VEAF, l'assistant crée la campagne, la valide et prépare le `.miz` à envoyer sur le serveur.
- Deux nouvelles actions : `campaign_init` pose l'exemple livré (campagne persistante ou multi-missions), et `campaign_validate` rend les erreurs et avertissements de `campaign validate`.
- L'assistant peut lire et modifier `campaign.yaml` et `briefing.yaml`.
- Un prompt de départ « campagne persistante » : les questions à vous poser, puis l'ordre de travail, de l'exemple jusqu'au `.miz`.
- Nouvelle section *Avec une IA* dans la page *Campagne persistante*, et une section *Campagne persistante* dans le catalogue de l'IA.

---

## 📻 Menus radio

- **« Page suivante » est toujours la dernière entrée d'une page de menu.** Une entrée ajoutée après coup (le groupe d'un pilote qui rejoint, une entrée recréée) se plaçait en dessous, et le menu F10 n'était plus le même que le F9.

---

## 🌍 Campagne persistante : ce que la soirée du 22/11 a montré

- Une capture en cours affiche le temps restant avant la prise (« prise dans 4 min 30 s »), sur la carte F10 et dans la situation.
- Une zone n'est plus réparée tant qu'un véhicule d'un convoi ennemi est à moins de 5 km de son centre (`network.threat_radius`).
- Un convoi d'assaut ne tourne plus en boucle devant une zone sur des ennemis qu'il ne voit pas.
- L'infanterie d'une garnison tient une seule position près du centre de la zone (`infantry_radius`, 600 m), hors du béton et des bâtiments.

---

## 🔧 Corrections

Un avion recréé ou téléporté par VEAF (AWACS et ravitailleurs rachetés en boutique, `veafAssets.respawn`) garde l'indicatif de l'éditeur de mission : ses appels radio échouaient avec « Callname -1 not found ».
