# VEAF Mission Creation Tools — 6.7.8

Version **de fiabilité**, à nouveau sur un retour de **Tripack**. Elle corrige un plantage au démarrage qui, dès qu'un module bien précis était activé, désactivait silencieusement les spawns par marqueur sur la carte F10 (alias `_spawn`, `-shilka`, `-sa2`…) ainsi que CTLD et CSAR — **même avec `SHORTCUTS: true`**. Aucune modification de configuration requise pour les missions existantes.

## 🐛 Corrections

- **Les spawns par marqueur F10 (et CTLD/CSAR) ne sont plus cassés par le module MissileGuardian** — quand `MISSILEGUARDIAN` était activé, l'initialisation VEAF plantait sur une fonction inexistante (`dumpMissionsList`), ce qui interrompait tout le reste de la séquence de démarrage. Conséquence : le dispatcher central des marqueurs F10 n'était jamais branché — donc `_spawn` et **tous** les alias de raccourcis restaient inertes malgré `SHORTCUTS: true` — et CTLD comme CSAR ne s'initialisaient pas non plus. Le démarrage se déroule désormais entièrement.

## ⚙️ Changement de comportement à noter

- **`MISSILEGUARDIAN` n'est plus activé automatiquement** — ce module (un outil de training expérimental, resté inachevé depuis 2021) était classé dans le template `full` et se retrouvait donc à `true` d'office sur un `prepare --tier full` ou un `convert-v5`. Il est désormais **opt-in** : proposé uniquement si vous le cochez explicitement dans le picker `custom`, jamais activé par défaut. Les missions qui l'utilisent volontairement (avec `MISSILEGUARDIAN: true` déjà écrit) ne sont pas affectées.

## 🙏 Remerciements

Merci à **Tripack** pour le signalement et le dossier de mission qui a permis de reproduire et corriger le cas précisément.
