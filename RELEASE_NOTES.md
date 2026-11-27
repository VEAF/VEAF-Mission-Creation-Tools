# VEAF Mission Creation Tools — 6.40.0

**Le serveur MCP VEAF fonctionne avec un modèle local, et `ai-setup` branche Cherry Studio.**

---

## 🤖 Le MCP avec un modèle local

- **Un profil compact** pour les modèles à petit contexte (65 000 tokens) : `VEAF_MCP_PROFILE=compact` dans la configuration MCP du serveur. Les réponses de la chaîne de référence passent de 177 000 à 39 000 caractères, et le guide se lit par sections avec une recette appel par appel. Le profil standard, celui de Claude Desktop, ne change pas.
- **Quatre invites, une par type de mission** : Mission one-shot, Open Training, Mission dynamique, Campagne persistante. Le client (Cherry Studio, par exemple) demande chaque argument, puis place un message court dans la zone de saisie.
- **Une nouvelle action `list_airfield_aircraft`** : les types d'appareils qu'une base offre, avec les noms exacts que le build attend (`F-16C_50`, `AV8BNA`). Un type mal écrit reçoit un « did you mean ».
- **Deux actions envoyées en même temps ne s'écrasent plus** : l'une effaçait l'aérodrome de l'autre, et les deux répondaient « succès ».
- **Le délai d'une QRA est documenté tel qu'il fonctionne** : il compte depuis la première intrusion jusqu'au décollage, pas depuis le début de la mission. Rien ne change en jeu.

---

## 🍒 Cherry Studio

- **`veaf-tools ai-setup` branche Cherry Studio** : avec Cherry fermé, il règle le serveur `veaf` dans sa base, après une sauvegarde. Il refuse sans écrire si Cherry tourne ou si la structure de la base est inconnue (testé avec Cherry 2.2.3).
- `--only cherry` ne règle que Cherry. `--cherry-assistant "NOM"` lie un assistant au serveur. `--cherry-data-dir DOSSIER` vise un profil lancé avec `--user-data-dir`.

---

## 🇩🇪 Cold War Germany sur DCS 2.9.32

- **20 aérodromes ajoutés par DCS** (Ahlhorn, Stuttgart, Lahr, Strasbourg…) se résolvent par leur nom : une QRA ou un entrepôt qui les nomme est câblé.
- Villes, fréquences et catalogue `clear-ground` recalculés sur la 2.9.32.
- Kola : ses trois nouveaux aérodromes attendent une capture.

---

## 📋 Briefing

- Chaque page de zone indique son waypoint (`Point : W4/H4`).
