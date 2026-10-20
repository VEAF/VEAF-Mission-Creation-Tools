# Installer l'assistant IA de création de missions

> **Public** : créateurs de missions VEAF qui veulent créer et éditer une mission en langage naturel avec un assistant IA (Claude, Gemini ou une autre IA), branché sur le serveur `veaf-mission-mcp`.

Les outils VEAF contiennent tout ce dont l'assistant a besoin : le serveur MCP qui agit sur vos missions (les « mains »), le guide de création qui lui dit comment s'y prendre (le « cerveau »), les limites connues des outils et de DCS, et les consignes pour construire une mission complète.
Rien à chercher ailleurs, ni sur GitHub ni dans la documentation : une fois les outils installés et l'assistant branché, demandez-lui simplement « crée une mission ».
Le catalogue de ce que vous pouvez lui demander est dans [AI_ASSISTANT_CATALOG.md](AI_ASSISTANT_CATALOG.md).

> **En cinq étapes**
>
> 1. Choisissez une IA dans le tableau [Quelle IA choisir ?](#which-ai), par exemple OpenCode.
> 2. Installez-la sur votre PC, et ouvrez-y un compte si elle en demande un.
> 3. Lancez-la et dites-lui : « installe les outils IA VEAF : https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/ ».
>    Avec Claude Desktop en mode chat, qui ne lance pas de commande, tapez plutôt vous-même [les cinq commandes](#for-an-ai-assistant) dans PowerShell.
> 4. Quand elle vous le demande, quittez-la complètement et relancez-la : elle ne lit ses outils qu'au démarrage.
> 5. Dites-lui : « crée une mission DCS ».

## Quelle IA choisir ? {#which-ai}

Il faut une application qui sait lancer un serveur MCP **sur votre PC** : les chats dans le navigateur (ChatGPT web, Le Chat, l'appli Gemini) ne le peuvent pas.
Les offres gratuites changent souvent ; ce tableau date d'octobre 2026, et aucun éditeur ne publie le quota gratuit exact.

| Application | Gratuit | Ce qu'elle fait avec VMCT |
|---|---|---|
| **Claude Desktop** (mode chat) | plan gratuit, quota limité ; Anthropic ne dit pas si ce plan accepte un serveur local (à vérifier) | la plus simple pour commencer : elle construit la mission et son briefing avec les actions VEAF, mais ne lance aucun programme sur votre PC — ni l'installation, ni les cartes et le README d'une Open Training |
| **ChatGPT Desktop, onglet Codex** | inclus dans le plan gratuit, quota limité | tout, installation comprise ; interface orientée développeurs |
| **OpenCode** | modèles gratuits proposés pour une durée limitée | tout, installation comprise ; s'utilise dans un terminal |
| **Antigravity** (Google) | gratuit, quotas hebdomadaires | tout, installation comprise ; c'est un éditeur de code |
| **Claude Code** | abonnement Claude payant | tout ; c'est l'outil avec lequel VMCT est développé |

**Gemini CLI** reste branché par `ai-setup`, mais il ne sert plus les comptes Google gratuits depuis juin 2026 : Google le remplace par Antigravity.

## Pour un assistant IA : tout installer {#for-an-ai-assistant}

Cette section se lit aussi par l'IA elle-même : dites-lui « installe les outils VEAF en suivant https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/ » et elle fait ce qui suit.
Il faut pour cela une IA qui sait lancer des commandes sur votre PC, comme Codex, OpenCode, Antigravity ou Claude Code.
**Claude Desktop en mode chat ne le peut pas** : tapez alors ces commandes vous-même, dans PowerShell (menu Démarrer → « PowerShell ») :

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\VEAF\outils" | Out-Null
Set-Location "$env:USERPROFILE\VEAF\outils"
Invoke-WebRequest https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/download/published-latest/veaf-tools-updater.exe -OutFile veaf-tools-updater.exe -UseBasicParsing
.\veaf-tools-updater.exe
.\veaf-tools.exe ai-setup
```

1. Le dossier `%USERPROFILE%\VEAF\outils` reçoit les outils : c'est leur place définitive, à part de vos missions.
2. `veaf-tools-updater.exe` télécharge la dernière version et installe `veaf-tools.exe` à côté de lui.
3. `veaf-tools.exe ai-setup` branche le serveur dans chaque assistant IA installé sur le PC — Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI, OpenCode — et dit pour chacun ce qu'il a fait.

Ensuite, **quittez complètement l'assistant IA et relancez-le** : il ne lit ses serveurs qu'au démarrage.
Si vous tapez les commandes vous-même pour Claude Desktop, quittez-le **avant** `ai-setup` : il garde ses réglages dans le même fichier, et pourrait réécrire sa propre copie par-dessus.

> **Sécurité Windows** : si Windows bloque un `.exe` téléchargé, clic droit → **Propriétés** → cochez **Débloquer** → **OK**.

**Comment savoir que ça marche** : demandez à l'assistant « quelle version de veaf-tools utilises-tu ? ».
Il doit répondre avec la version installée, celle qu'affiche `.\veaf-tools.exe about`.

## Utiliser l'assistant {#use}

Demandez en langage naturel.
Pour une nouvelle mission, « crée une mission » suffit : l'assistant vous demande laquelle des deux sortes vous voulez, puis charge les consignes qui vont avec.

- **Une mission à objectifs, jouée en une séance** : un package, un ou plusieurs objectifs, une menace, un retour.
  L'assistant demande la carte, les appareils et le nombre de pilotes, la durée de la séance et le genre de mission, puis **propose un scénario**.
  Vous en demandez d'autres autant que vous voulez, vous posez vos questions ; rien n'est écrit tant que vous n'avez pas validé un scénario.
  Ensuite il construit la mission et son briefing.
- **Une mission Open Training** : une mission d'entraînement VEAF sur une carte entière — bases, soutien, défense aérienne, zones d'entraînement graduées, zones de combat, QRA, CAP, météo.
  L'assistant ne pose que quatre ou cinq questions : la carte, l'époque, le gabarit, une éventuelle mission dont s'inspirer, les escortes.

Il vous demande aussi où créer le dossier de la mission, s'il n'en a pas déjà un.
Le briefing d'une mission à objectifs — document, cartes, images du briefing DCS — est produit par les outils eux-mêmes, même avec Claude Desktop en mode chat ; les cartes et le README d'une Open Training, et le PDF, demandent encore une IA qui lance des programmes, et une IA qui ne le peut pas vous dit ce qu'elle n'a pas pu produire.
Pour modifier une mission existante, donnez-lui le chemin de son dossier et décrivez ce que vous voulez :

> « Dans ma mission `Documents\VEAF\Missions\Syrie`, ajoute une combat zone de SAM longue portée au nord de Damas. »

L'assistant place les éléments, valide et construit le `.miz` sans que vous quittiez la conversation.

## Mises à jour {#updates}

Le serveur se met à jour tout seul : au démarrage de l'assistant, au plus une fois toutes les 4 heures, il regarde si une version plus récente est sortie et lance alors l'updater en arrière-plan, dans son dossier.
La nouvelle version sert au démarrage suivant de l'assistant.
Pour couper ce comportement, le même réglage coupe aussi l'annonce des nouvelles versions dans le terminal : `.\veaf-tools.exe user-config --set check_updates=false`.
On peut toujours mettre à jour à la main, en relançant `.\veaf-tools-updater.exe` dans le dossier des outils.

Si vous déplacez le dossier des outils, relancez `.\veaf-tools.exe ai-setup` depuis son nouvel emplacement : l'assistant lance l'exécutable par son chemin complet.

## Une autre IA compatible MCP {#other-mcp-client}

`ai-setup` connaît Claude Desktop, Claude Code, Codex, Antigravity, Gemini CLI et OpenCode.
Le serveur VEAF est un programme standard : n'importe quelle autre IA qui sait lancer un **serveur MCP local** peut s'en servir, une fois déclaré à la main.
Toutes ces IA demandent les deux mêmes informations : la **commande** (le chemin complet de `veaf-tools.exe`) et ses **arguments** (`mcp`).
La plupart les lisent dans un fichier JSON de cette forme :

```json
{
  "mcpServers": {
    "veaf-mission-editor": {
      "command": "C:\\Users\\<vous>\\VEAF\\outils\\veaf-tools.exe",
      "args": ["mcp"]
    }
  }
}
```

> **Les barres obliques inverses sont doublées** : c'est la règle du JSON, une seule `\` y est un caractère spécial.
> Écrire le chemin tel qu'il s'affiche dans l'explorateur rend le fichier illisible.

Cherchez « MCP » dans la documentation de votre IA : le nom du fichier change, les deux informations restent les mêmes.
Le serveur demande à l'IA de lire son guide de création avant toute action, mais toutes les IA ne tiennent pas compte de cette demande ; si la vôtre se met à deviner, commencez la conversation par :

> « Avant toute chose, lis le guide de création VEAF avec l'action `describe_authoring_guide`, puis les limites connues avec `describe_known_limitations`. »

## Une IA sans MCP {#no-mcp}

Une IA de chat dans le navigateur ne peut pas lancer de programme sur votre PC : elle ne lit pas votre mission, ne la modifie pas, ne la construit pas.
Elle reste utile pour **comprendre** et **rédiger** : expliquer une option, proposer un bloc de `mission.yaml`, relire un message d'erreur.
Pour qu'elle ne réponde pas de mémoire, donnez-lui la page qui fait foi — la [référence `mission.yaml`](../MISSION_YAML_REFERENCE.md), la fiche du script concerné — en la collant dans la conversation ou en lui donnant son adresse.
Puis vérifiez ce qu'elle propose avec `.\veaf-tools.exe validate` avant de construire : c'est vous qui faites tourner les outils.

## Tester une pré-release (avancé) {#pre-release}

Pour éprouver une **pré-release**, installez-la à la place de la version stable en passant son tag à l'updater :

```powershell
.\veaf-tools-updater.exe --tag published-v6.9.21-rc1
```

Les missions que l'assistant crée ensuite reçoivent la même version si la variable `VEAF_MCP_UPDATER_TAG` porte ce tag au démarrage de l'assistant : `$env:VEAF_MCP_UPDATER_TAG = "published-v6.9.21-rc1"`.
Tant que cette variable est posée, le serveur ne se met pas à jour tout seul : il reste sur la pré-release que reçoivent les missions.
