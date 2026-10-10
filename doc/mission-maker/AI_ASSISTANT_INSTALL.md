# Installer l'assistant IA de création de missions

> **Public** : créateurs de missions VEAF qui veulent créer et éditer une mission en langage
> naturel via un assistant IA (Claude, Gemini ou une autre IA), branché sur le serveur `veaf-mission-mcp`.

Le plugin **veaf-mission-editor** apporte à votre assistant les outils VEAF (le serveur MCP —
les « mains ») et le savoir-faire d'authoring (la skill — le « cerveau »). Une fois installé, vous
demandez une mission en français et l'assistant l'enchaîne : création → édition → validation →
build. Le catalogue de ce que vous pouvez demander est dans
[AI_ASSISTANT_CATALOG.md](AI_ASSISTANT_CATALOG.md).

Le savoir-faire est le même quelle que soit l'IA — un seul fichier de consignes, pas une copie par assistant.
Choisissez la ligne qui correspond à la vôtre :

| Votre IA | Ce qu'elle peut faire | Section |
|---|---|---|
| **Claude Code** (en terminal, ou l'onglet **Code** de l'application Claude) | tout, et elle installe `veaf-tools` toute seule | [Installation avec Claude Code](#install-claude-code) |
| **Gemini CLI** | tout, si `veaf-tools` est déjà installé | [Installation avec Gemini CLI](#install-gemini-cli) |
| Une autre IA qui sait lancer un **serveur MCP** sur votre PC (Claude Desktop en mode chat, éditeurs de code avec assistant…) | tout, une fois branchée à la main | [Une autre IA compatible MCP](#other-mcp-client) |
| Une IA de chat dans le navigateur (ChatGPT, Le Chat, Gemini web…) | conseiller, pas agir sur vos fichiers | [Une IA sans MCP](#no-mcp) |

## Prérequis

- **Claude Code**, **Gemini CLI** ou une autre IA compatible MCP installée.
- **Windows** (le plugin est Windows-first ; les créateurs de missions DCS sont sous Windows).

## Installation avec Claude Code {#install-claude-code}

Dans un terminal — ou via les commandes `/plugin …` directement dans Claude Code :

```powershell
git config --global core.longpaths true   # Windows : autorise les chemins longs au clone du marketplace
claude plugin marketplace add VEAF/VEAF-Mission-Creation-Tools
claude plugin install veaf-mission-editor@veaf
```

Puis **redémarrez Claude Code**. (Dépôt public : aucune authentification nécessaire.)

> **Windows :** la 1re ligne évite un échec de clone « Filename too long » (limite des 260
> caractères). Si `add` a déjà échoué pour cette raison, supprimez le clone partiel sous
> `~/.claude/plugins/marketplaces/` puis réessayez. En cas de refus de clé SSH sur une machine
> neuve, forcez HTTPS : `git config --global url."https://github.com/".insteadOf "git@github.com:"`.

## Installation avec Gemini CLI {#install-gemini-cli}

Gemini installe une extension depuis un dossier de votre disque, et il veut trouver le fichier
d'extension à la racine de ce dossier — chez nous il est dans le sous-dossier `plugin`. D'où le clone
d'abord, l'installation ensuite :

```powershell
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
gemini extensions install VEAF-Mission-Creation-Tools/plugin
```

Puis **redémarrez Gemini CLI** : les extensions ne sont prises en compte qu'au démarrage d'une
nouvelle session.

Gemini recopie l'extension **dans votre dossier personnel**, sous
`%USERPROFILE%\.gemini\extensions\veaf-mission-editor\`. Rien n'est écrit ailleurs. Pour la retirer :

```powershell
gemini extensions uninstall veaf-mission-editor
```

> **Une différence à connaître** : avec Claude Code, l'outil `veaf-tools` s'installe et se met à jour
> tout seul (voir la section suivante). **Avec Gemini, non** : il faut que `veaf-tools` soit déjà
> installé sur votre machine et accessible depuis un terminal — tapez `veaf-tools --help` pour le
> vérifier. Si la commande n'est pas reconnue, installez les outils VEAF avant d'utiliser l'assistant.

## Une autre IA compatible MCP {#other-mcp-client}

Le serveur VEAF est un programme standard : n'importe quelle IA qui sait lancer un **serveur MCP local** peut s'en servir.
Le plugin, lui, n'existe que pour Claude Code et Gemini CLI, donc deux choses se font à la main : installer `veaf-tools`, et déclarer le serveur.

**1. Installer `veaf-tools`.**
Suivez l'[étape 0 du tutoriel](TUTORIAL.md#step-0-install) dans un dossier qui ne bougera plus, par exemple `C:\VEAF\outils` — l'étape parle d'un dossier de mission ; ici, c'est le dossier des outils, à part de vos missions.
Notez le chemin complet de `veaf-tools.exe` : l'IA le lance elle-même, sans passer par un terminal ouvert dans ce dossier.
Ce `veaf-tools.exe` sert de serveur ; chaque mission que l'IA crée reçoit ensuite ses propres outils dans son dossier, comme au tutoriel.
Pensez à relancer `veaf-tools-updater.exe` dans `C:\VEAF\outils` de temps en temps : avec Claude Code, le plugin le fait à votre place ; ici, personne.

**2. Déclarer le serveur.**
Toutes ces IA demandent les deux mêmes informations : la **commande** (le chemin de `veaf-tools.exe`) et ses **arguments** (`mcp`).
La plupart les lisent dans un fichier JSON de cette forme :

```json
{
  "mcpServers": {
    "veaf-mission-editor": {
      "command": "C:\\VEAF\\outils\\veaf-tools.exe",
      "args": ["mcp"]
    }
  }
}
```

> **Les barres obliques inverses sont doublées** : c'est la règle du JSON, une seule `\` y est un caractère spécial.
> Écrire `C:\VEAF\outils\veaf-tools.exe` tel quel rend le fichier illisible.

Avec **Claude Desktop** (l'application Claude, en mode chat) : menu **Paramètres** (*Settings*) → **Développeur** (*Developer*) → **Modifier la configuration** (*Edit Config*).
Le fichier qui s'ouvre est `%APPDATA%\Claude\claude_desktop_config.json` ; ajoutez-y le bloc `mcpServers` ci-dessus — s'il contient déjà d'autres réglages, gardez-les et ajoutez seulement la clé — puis **quittez complètement** l'application et relancez-la.
Pour une autre IA, cherchez « MCP » dans sa documentation : le nom du fichier change, les deux informations restent les mêmes.

**3. Lui donner le savoir-faire.**
C'est ce que le plugin apporte et qui manque ici : les conventions de nommage, l'ordre de travail, ce qu'il faut vérifier plutôt que deviner.
Sans elles, l'IA construit des missions qui ont l'air justes et ne marchent pas dans DCS, sans aucune erreur visible.
Le serveur les sert lui-même — l'action `describe_authoring_guide` renvoie le même texte que le plugin — et demande à l'IA de les lire en premier.
Toutes les IA ne tiennent pas compte de cette demande, donc commencez chaque conversation par :

> « Avant toute chose, lis le guide de création VEAF avec l'action `describe_authoring_guide`, puis les limites connues avec `describe_known_limitations`. »

**Comment savoir que ça marche** : demandez « quelle version de veaf-tools utilises-tu ? ».
L'IA doit répondre avec la version installée, celle qu'affiche `.\veaf-tools.exe about`.

## Une IA sans MCP {#no-mcp}

Une IA de chat dans le navigateur ne peut pas lancer de programme sur votre PC : elle ne lit pas votre mission, ne la modifie pas, ne la construit pas.
Elle reste utile pour **comprendre** et **rédiger** : expliquer une option, proposer un bloc de `mission.yaml`, relire un message d'erreur.
Pour qu'elle ne réponde pas de mémoire, donnez-lui la page qui fait foi — la [référence `mission.yaml`](../MISSION_YAML_REFERENCE.md), la fiche du script concerné — en la collant dans la conversation ou en lui donnant son adresse.
Puis vérifiez ce qu'elle propose avec `.\veaf-tools.exe validate` avant de construire : c'est vous qui faites tourner les outils.

## Premier démarrage (Claude Code)

Au premier lancement, le plugin **installe tout seul** l'outil `veaf-tools` (via
`veaf-tools-updater`) dans son dossier de données — rien à copier à la main. L'assistant peut être
**indisponible quelques secondes** le temps de cette première installation : dans ce cas,
**relancez Claude Code** une fois. Ensuite, `veaf-tools` se met à jour automatiquement (au plus une
fois toutes les 4 h).

> **Sécurité Windows** : si Windows bloque un `.exe` téléchargé, clic droit → **Propriétés** →
> cochez **Débloquer** → **OK**.

## Utiliser l'assistant

Ouvrez Claude Code dans le dossier de votre mission (ou un dossier vide pour partir de zéro) et
demandez en langage naturel, par exemple :

> « Crée une mission sur la Syrie avec une combat zone de SAM longue portée au nord de Damas. »

L'assistant crée le dossier, pose une carte blanche du théâtre, place les éléments, puis valide et
construit le `.miz` — sans que vous quittiez la conversation.

### Une mission Open Training complète

Pour une mission d'entraînement VEAF entière — bases, soutien, défense aérienne, zones
d'entraînement graduées, zones de combat, QRA, CAP, météo — collez au début de la session le prompt
[`.prompts/new-open-training-mission.fr.md`](../../.prompts/new-open-training-mission.fr.md), dans
un dossier vide (version anglaise :
[`new-open-training-mission.en.md`](../../.prompts/new-open-training-mission.en.md)). Il fixe les règles de conception (quelles bases, combien de zones, quelle défense
selon la taille du front) et ne pose que quatre ou cinq questions : la carte, l'époque, le gabarit,
une éventuelle mission dont s'inspirer, les escortes.

### Une mission à objectifs, jouée en une séance

Pour une mission qu'un groupe joue une fois — un package, un ou plusieurs objectifs, une menace, un
retour —, collez le prompt
[`.prompts/new-objective-mission.fr.md`](../../.prompts/new-objective-mission.fr.md) dans un dossier
vide (version anglaise :
[`new-objective-mission.en.md`](../../.prompts/new-objective-mission.en.md)). Il demande la carte,
les appareils et le nombre de pilotes (slots nommés ou dynamiques), la durée de la séance et le genre de mission, puis **propose
un scénario** : vous en demandez d'autres autant que vous voulez, vous posez vos questions, vous
pouvez faire afficher le briefing dans la conversation. Rien n'est écrit tant que vous n'avez pas
validé un scénario ; ensuite, l'assistant construit la mission et son briefing en PPTX (à importer en Google Slides) et/ou PDF,
au format des briefings VEAF.

## Mettre à jour le plugin

Quand une nouvelle version du plugin sort, avec Claude Code :

```powershell
claude plugin marketplace update veaf
claude plugin update veaf-mission-editor@veaf
```

(La mise à jour de `veaf-tools` lui-même est **automatique** et indépendante de celle du plugin.)

Avec Gemini CLI, mettez à jour le clone puis l'extension :

```powershell
git -C VEAF-Mission-Creation-Tools pull
gemini extensions update veaf-mission-editor
```

## Tester une pré-release (avancé)

Par défaut, le plugin suit la version **stable**. Pour éprouver une **pré-release**, définissez une
variable d'environnement **avant** de lancer Claude Code :

```powershell
$env:VEAF_MCP_UPDATER_TAG = "published-v6.9.21-rc1"
```

Le plugin installera alors cette version au lieu de la stable. Retirez la variable pour revenir au
comportement normal.

## Commandes utiles

```powershell
claude plugin list                                # plugins installés
claude plugin marketplace list                    # marketplaces enregistrés
claude plugin disable veaf-mission-editor@veaf    # désactiver sans désinstaller
```

Côté Gemini CLI :

```powershell
gemini extensions list                            # extensions installées
gemini extensions uninstall veaf-mission-editor   # retirer l'extension
```
