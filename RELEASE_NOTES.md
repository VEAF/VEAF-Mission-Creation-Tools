# VEAF Mission Creation Tools — 6.31.0

**Cette version est celle de la mission créée avec une IA, sans rien d'autre que les outils VEAF.**
Une démo enregistrée sur un Windows vierge ne se comportait pas comme sur le PC qui développe VMCT : il lui manquait un plugin, le dépôt, et des savoirs restés dans la mémoire d'un assistant.
Désormais, installer les outils et taper une commande suffit à brancher Claude, Codex, OpenCode ou Antigravity ; ensuite, « crée une mission » suffit.
L'assistant répond aux questions de relief sans DCS ouvert, et produit le briefing VEAF même sans pouvoir lancer de programme.
Côté jeu : une opposition sans avions, les options de mission imposées à tous les joueurs, l'éclairage du pont qui suit les opérations aériennes, et une planchette de fréquences redessinée.

> ### ⚠️ Ce qui change pour vous
>
> **1. Le plugin Claude Code et l'extension Gemini disparaissent.**
> Désinstallez-les (`claude plugin uninstall veaf-mission-editor@veaf`, ou `gemini extensions uninstall veaf-mission-editor`), puis lancez `.\veaf-tools.exe ai-setup` depuis le dossier de vos outils : il branche toutes les IA installées sur le PC.
>
> **2. Le plan de fréquences livré n'a plus de canal Guard.**
> Le canal 1 devient la fréquence de départ du vol, et un vol démarrait sur la fréquence de détresse ; chaque appareil atteint Guard par sa propre commande.
> Les canaux descendent d'un cran : Archer passe au canal 1 en UHF, Batumi au canal 1 en VHF.
> Seules les **nouvelles** missions sont concernées : une mission existante garde son `presets.yaml`.

---

## 🤖 Créer une mission avec une IA

- **Une commande branche votre IA** : `.\veaf-tools.exe ai-setup` déclare le serveur VEAF dans Claude Desktop, Claude Code, Codex (l'onglet Codex de ChatGPT Desktop), Antigravity, Gemini CLI et OpenCode, sans toucher à leurs autres réglages.
  L'updater la propose à la première installation, et le menu interactif la liste.
- **Une IA qui sait lancer des commandes s'installe toute seule** : dites-lui « installe les outils IA VEAF en suivant https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/ ».
- **« Crée une mission » suffit** : les deux prompts de mission, à objectifs et Open Training, sont livrés dans l'exécutable avec le guide de création ; plus rien à copier depuis le dépôt.
  Toute nouvelle mission commence par adapter ce que le squelette livre : plan de fréquences, date, waypoints d'exemple, Skynet dès qu'il y a de la défense aérienne.
- **Le briefing VEAF sans script** : la nouvelle action `build_mission_briefing` écrit le briefing d'une mission à objectifs (`docs/briefing.pptx`, neuf pages), ses cartes, et les met dans le briefing DCS, même depuis Claude Desktop en mode chat.
- **Une IA sans accès à vos fichiers peut modifier la mission** : `read_mission_file` et `edit_mission_file` lisent et modifient `mission.yaml` et les `src/*.yaml`, avec une sauvegarde avant chaque écriture ; renommer la mission ou changer son époque ne bloque plus.
- **Le serveur se met à jour tout seul**, au plus une fois toutes les 4 heures, et la nouvelle version sert au démarrage suivant de l'IA.
- **Quelle IA choisir ?** La page « Créer avec une IA » commence par un tableau des IA utilisables, offres gratuites comprises.

---

## 🗺️ Le relief sans DCS

- **Les grilles d'altitude se téléchargent quand le PC n'en a pas** : altitude du sol, masquage par le relief et contrôles de pente répondent sans DCS ouvert.
  Onze cartes sont publiées : Afghanistan, Caucasus, Falklands, GermanyCW, Mariana Islands, Mariana Islands WWII, Normandy, Persian Gulf, Sinai, Syria et The Channel.
  Une grille relevée sur votre PC reste prioritaire.
- **The Channel est un théâtre pris en charge**, avec sa mission vierge.

---

## ✈️ En jeu

- **« 0 avion » coupe la chasse adverse** : *Opposition → Niveau → 0 avion*, ou le marqueur `_opposition 0`, garde au sol les QRA qui suivent l'opposition, jusqu'à ce qu'on remonte le niveau.
- **Les options de mission imposées à tous les joueurs, depuis `mission.yaml`** : `mission.forced_options` fixe à chaque build ce qu'impose le panneau *Options de mission* de l'éditeur (étiquettes, vue F10, vues externes, marques F10, turbulence de sillage, effets G…), et `f10_view_by_role` la carte F10 de chaque rôle.
- **L'éclairage du pont du porte-avions suit les opérations aériennes VEAF** : feux d'appontage quand elles commencent, retour à DCS quand elles s'arrêtent.
- **La planchette des fréquences est redessinée pour la fenêtre où DCS l'affiche** : elle était étirée à 60 % de sa largeur.
  Chaque radio porte son nom de cockpit (`COMM 1 · ARC-210`), s'arrête à son dernier canal, et une page de calibration aide le pilote qui a redimensionné sa fenêtre.
- **Une page d'astuces de l'éditeur de mission** : les actions de déclencheur que VMCT n'enveloppe pas et qui valent d'être connues.

---

## 🛠️ Corrections

- **Les départs au parking et en piste marchent depuis l'exécutable** : les données de parking n'y étaient pas embarquées, et une QRA en départ piste échouait sur « no parking data captured » alors qu'elle fonctionnait depuis le dépôt.
- **L'updater remplace un `veaf-tools.exe` en cours d'exécution**, et se remplace lui-même : un serveur MCP était resté cinq semaines sur une ancienne version sans que personne le voie.
- **L'annonce d'une nouvelle version s'affiche** : elle lisait la version au mauvais endroit.
- **Un vol nommé d'après une famille d'indicatifs la reçoit** : un AWACS nommé « Magic » devenait « Overlord » sans prévenir.
- **Le rapport des presets ne conseille plus `none`** pour un canal hors de portée que DCS ignore de toute façon : `none` retire tous les presets du type, y compris ceux qui marchent.
- **Déplacer un point de route fonctionne** (`edit_route` `set`), au lieu d'ignorer la nouvelle position sans rien dire.
- **`build_mission_briefing` ne supprime que les images qu'il a écrites** : le nom d'une ancienne image venait de la mission, et une mission venue d'ailleurs pouvait faire supprimer un fichier hors de son dossier.
- **Foothold** : `convert-other --update` suit le passage de Lekaa à `zoneCommanderv2.lua` en 5.3.0, et `validate` signale un module retiré au lieu d'échouer.

---

## 🙏 Merci

À **Fullgas**, dont la session de création de mission avec Claude a fait apparaître plusieurs des défauts corrigés ici.
