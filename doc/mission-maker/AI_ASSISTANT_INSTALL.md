# Installer l'assistant IA de création de missions

> **Public** : créateurs de missions VEAF qui veulent créer et éditer une mission en langage
> naturel via un assistant IA (Claude Code), branché sur le serveur `veaf-mission-mcp`.

Le plugin **veaf-mission-editor** apporte à Claude Code les outils VEAF (le serveur MCP —
les « mains ») et le savoir-faire d'authoring (la skill — le « cerveau »). Une fois installé, vous
demandez une mission en français et l'assistant l'enchaîne : création → édition → validation →
build. Le catalogue de ce que vous pouvez demander est dans
[AI_ASSISTANT_CATALOG.md](AI_ASSISTANT_CATALOG.md).

## Prérequis

- **Claude Code** installé.
- **Windows** (le plugin est Windows-first ; les créateurs de missions DCS sont sous Windows).

## Installation

Dans un terminal — ou via les slash commands `/plugin …` directement dans Claude Code :

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

## Premier démarrage

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

## Mettre à jour le plugin

Quand une nouvelle version du plugin sort :

```powershell
claude plugin marketplace update veaf
claude plugin update veaf-mission-editor@veaf
```

(La mise à jour de `veaf-tools` lui-même est **automatique** et indépendante de celle du plugin.)

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
