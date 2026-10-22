# VEAF Mission Creation Tools — 6.31.3

**Une version corrective de la 6.31.x : une IA qui vous parle anglais fait une mission en anglais, cinq cartes de plus ont leurs places de parking, et deux défauts en jeu sont corrigés.**

---

## 🤖 Créer une mission avec une IA

- **Une mission dans la langue de celui qui la demande.**
  Les prompts de mission anglais imposaient une mission, un briefing et un README en français, « la langue des serveurs VEAF » : un utilisateur qui parlait anglais à son IA recevait des documents en français.
  La mission prend maintenant la langue dans laquelle vous parlez à l'IA, sauf si vous en demandez une autre.
- **Les slots dynamiques ne dépendent pas des données de parking.**
  Une IA a écrit qu'il n'y avait « pas de places de parking pour les slots dynamiques » sur GermanyCW, trompée par le nom d'une limitation connue.
  C'est DCS qui place les joueurs des slots dynamiques, sur toutes les cartes ; la limitation dit maintenant ce qu'elle concerne vraiment : les départs au sol des vols que placent les outils.

## 🗺️ Cinq cartes de plus avec leurs places de parking

Afghanistan, GermanyCW, Mariana Islands, Mariana Islands WWII et The Channel, relevées dans DCS le 22 octobre :

| Carte | Aérodromes | Places |
|---|---|---|
| Afghanistan | 26 | 1 435 |
| GermanyCW | 227 | 7 035 |
| Mariana Islands | 8 | 282 |
| Mariana Islands WWII | 11 | 534 |
| The Channel | 12 | 616 |

Un vol ou une QRA peut y démarrer sur une place de parking ou en bout de piste, et le build ne propose en slot dynamique, sur chaque aérodrome, que ce qu'il peut garer.
Seules Iraq, Kola et Nevada restent sans.

## ✈️ En jeu

- **« 0 avion » arrête aussi la « Taille auto » des combat missions.**
  Choisi dans le menu *Opposition*, « 0 avion » faisait taire les QRA, mais une combat mission lancée en *Taille auto (niveau d'opposition)* décollait quand même ; elle ne lance plus rien, et le dit à celui qui l'a demandée.
  Une taille choisie à la main se lance toujours.
- **Une écriture ratée n'efface plus l'état d'une campagne.**
  Disque plein, quota atteint : la mission ne vérifiait pas l'écriture de son fichier d'état, et un fichier tronqué pouvait remplacer le bon ; elle vérifie maintenant, et l'état précédent reste intact.

## 🔒 Sécurité

- **Pillow 13.0.0** (les images des cartes de briefing et de la planchette) et **certifi 2026.10.19** (les certificats qui sécurisent les téléchargements des outils) : 15 alertes de sécurité corrigées, dont deux critiques.

---

📖 Installer les outils pour une IA : [page d'installation](https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/)
