# VEAF Mission Creation Tools — 6.31.1

**Une version corrective de la 6.31.0, pour Claude Desktop installé depuis le Microsoft Store.**
Installé de cette façon, Claude Desktop peut ranger ses réglages ailleurs que là où `ai-setup` les cherchait : la commande répondait alors « non trouvé », et Claude Desktop restait sans les outils VEAF.

> ### ⚠️ Ce qui change pour vous
>
> **Si `ai-setup` vous a répondu que Claude Desktop n'était pas trouvé alors qu'il est installé**, mettez à jour les outils, quittez complètement Claude Desktop, puis relancez `ai-setup` depuis le dossier de vos outils :
>
> ```powershell
> .\veaf-tools-updater.exe
> .\veaf-tools.exe ai-setup
> ```
>
> Relancez ensuite Claude Desktop : il ne lit ses serveurs qu'au démarrage.

---

## 🛠️ Corrections

- **`ai-setup` trouve Claude Desktop installé depuis le Microsoft Store** quand celui-ci garde ses données dans `%LOCALAPPDATA%\Claude-Data\`, ce que fait la version 3.1623.
  Les autres installations sont branchées comme avant.
- **Le message de fin de première installation ne vous fait plus préparer une mission dans le dossier des outils** : il disait `prepare .`, juste quand l'updater est dans le dossier de la mission, faux quand il est dans `%USERPROFILE%\VEAF\outils` comme le propose la page d'installation pour une IA.
  Il dit maintenant `.\veaf-tools.exe prepare <dossier de la mission>`, avec `.` si ce dossier-ci est celui de la mission.
