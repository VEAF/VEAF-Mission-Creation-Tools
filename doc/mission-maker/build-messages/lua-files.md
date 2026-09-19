# Les fichiers Lua du dossier

Le build fait l'inventaire de `src/scripts/` à chaque construction, et vous dit ce qu'il y trouve
d'inattendu. Aucun de ces messages n'arrête le build, et aucun ne signifie qu'un fichier a été
perdu — mais leur ton peut laisser croire le contraire, ce qui est exactement ce qui a motivé cette
page.

## Les trois sortes de `.lua` {#three-kinds}

Le build classe chaque fichier de `src/scripts/` dans une de ces trois cases, et le message que
vous recevez dépend uniquement de la case :

| Sorte | Fichiers | Ce que le build en fait |
|---|---|---|
| **Attendus** | `mission-script.lua`, `veaf-config.lua`, `veafDynamicConfig.lua`, `ctld-config.yaml`, le script d'override | Il les traite, sans rien dire |
| **Déclarés** par vous | tout ce que `custom_scripts:` de `mission.yaml` énumère | Il les embarque, et l'annonce en mode bavard |
| **Générés** par lui-même | `veaf-spawn-data.lua`, `dcs-bridge.lua` | Il **ignore** la copie du dossier et injecte la sienne |

Tout le reste est « inattendu ». Ce n'est pas une accusation : c'est simplement un fichier dont le
build ne sait pas ce que vous en voulez.

## Un fichier Lua inattendu {#builder-unexpected-lua-file}

> Fichier Lua inattendu 'src/scripts/monScript.lua' trouvé dans votre dossier mission. Ce fichier
> sera inclus dans la construction. Vous pouvez le déclarer dans la section 'custom_scripts' de
> mission.yaml pour supprimer cet avertissement.

**Lisez bien la deuxième phrase : le fichier *est* embarqué.** Rien n'est laissé de côté, rien
n'est perdu. Le build vous signale seulement qu'il le charge sans savoir quand vous vouliez qu'il
le soit.

**Comment le reproduire.** Déposez n'importe quel `.lua` dans `src/scripts/` sans le déclarer, et
reconstruisez.

**Les issues.**

| Issue | Quand |
|---|---|
| Le déclarer dans `custom_scripts:` | C'est votre script et vous le voulez — vous gagnez au passage le contrôle de l'ordre et du délai de chargement |
| Le supprimer du dossier | C'est un résidu dont vous n'avez plus l'usage |
| Ne rien faire | Le message revient à chaque build, le script fonctionne |

**Ce que ce n'est pas.** Pas un fichier rejeté, pas une erreur de syntaxe, pas un conflit. Voir
[Scripts personnalisés](../concepts/custom-scripts.md) pour la déclaration.

## Un fichier que le build génère lui-même {#builder-generated-artifact-in-sources}

> 'src/scripts/veaf-spawn-data.lua' n'est pas un script écrit par quelqu'un : c'est la construction
> qui le génère et l'injecte dans la mission à chaque fois. Il arrive généralement là après
> l'extraction d'une mission déjà construite. Il est laissé de côté pour cette construction, donc
> rien n'est cassé — supprimez-le de votre dossier mission pour ne plus voir ce message. Ne le
> déclarez PAS dans 'custom_scripts:' : cela figerait une copie périmée dans votre mission.

**D'où il vient.** Vous avez extrait un dossier de mission depuis un `.miz` déjà construit.
L'extraction a rendu au dossier ce que le build y avait injecté — sa propre sortie, revenue en
entrée.

**Que faire.** Le supprimer du dossier. Votre mission reçoit de toute façon la version fraîche que
le build injecte ; celle du dossier ne sert à rien.

**Ce qu'il ne faut surtout pas faire.** Le déclarer dans `custom_scripts:`. C'est la seule action
qui casse réellement quelque chose : elle gèle dans votre mission une copie périmée de données que
le build régénère à chaque fois. Signalé par Tripack en septembre 2026, où deux copies des mêmes
tables se retrouvaient embarquées ensemble.

**Ce que ce n'est pas.** Pas une perte : le fichier est ignoré **pour cette construction**, pas
supprimé de votre disque, et la mission contient bien les données. Détail des fichiers concernés
dans [Scripts personnalisés](../concepts/custom-scripts.md#generated-artifacts).

## …et c'est la base de spawn {#builder-generated-artifact-spawn-data-hint}

> 'veaf-spawn-data.lua' contient la base de données de spawn utilisée par '_spawn unit' et '_spawn
> group'. Pour ajouter ou remplacer vos propres spawnables, modifiez 'src/spawn-groups.yaml' —
> jamais le Lua.

Le message précédent suivi de celui-ci, parce que c'est celui des deux fichiers générés que vous
pourriez légitimement vouloir modifier. La réponse est : oui, mais ailleurs — dans
`src/spawn-groups.yaml`, que le build lit pour fabriquer ce Lua. Voir
[Groupes spawnables](../concepts/spawnables.md).

## Ce script en charge d'autres {#builder-custom-loader-hint}

> 'src/scripts/monLoader.lua' semble charger d'autres scripts Lua (loadfile/dofile/require). En v6,
> plus besoin d'un loader custom : listez vos scripts dans la section 'custom_scripts:' de
> mission.yaml (chacun chargé au bon moment, avant/après mission-script.lua, avec un trigger de
> chargement généré automatiquement). Voir la documentation. Un loader v5 résiduel peut alors être
> supprimé.

**Ce que ça veut dire.** Votre fichier contient un `loadfile`, un `dofile` ou un `require`. En v5,
c'était la manière de charger plusieurs scripts ; en v6, `custom_scripts:` le fait à votre place,
avec en prime le contrôle de l'ordre et des délais.

**Il arrive toujours après le message précédent**, jamais seul : c'est une précision sur un fichier
déjà signalé comme inattendu.

**Les issues.** Migrer vers `custom_scripts:` puis supprimer le loader, ou le laisser tel quel — il
fonctionne toujours.

## Un fichier déclaré est bien pris en compte {#builder-custom-lua-included}

> Fichier Lua personnalisé 'src/scripts/monScript.lua' déclaré dans mission.yaml et sera inclus
> dans la construction.

**Rien à faire.** C'est une confirmation, pas un avertissement — la contrepartie exacte du message
« fichier inattendu ».

C'est un message de niveau *info* : dans un terminal interactif il s'affiche sur la ligne d'état,
qui se réécrit aussitôt, donc vous ne le verrez probablement passer que du coin de l'œil. Pour le
relire, ajoutez `--verbose`, ou redirigez la sortie vers un fichier — dans les deux cas les lignes
défilent et restent.

## Un script déclaré n'existe pas {#validate-custom-script-missing}

> custom_scripts : le script déclaré 'src/scripts/monScript.lua' n'existe pas.

**L'inverse des précédents** : `mission.yaml` annonce un fichier, le dossier ne le contient pas.
Faute de frappe dans le chemin, fichier jamais copié, ou script supprimé sans nettoyer la
déclaration.

**Les issues.** Corriger le chemin, ajouter le fichier, ou retirer l'entrée de `custom_scripts:`.

## MiST a été injecté pour vos scripts {#builder-mist-injected-for-custom-scripts}

> MiST n'est plus injecté par défaut, mais 'src/scripts/monScript.lua' l'utilise : il est injecté
> pour cette mission. Indiquez MIST: true sous modules: pour le demander explicitement.

**Tout va bien, et le build vous a rendu service.** MiST était historiquement embarqué dans toutes
les missions ; ce n'est plus le cas. Le build a vu que votre script y fait appel et l'a injecté
quand même, plutôt que de vous laisser découvrir un `mist` nul en vol.

**L'issue recommandée.** Écrire `MIST: true` sous `modules:` dans `mission.yaml` : la dépendance
devient explicite, et ne dépend plus de la capacité du build à la deviner dans votre code.

**Ce que ce n'est pas.** Pas une erreur, et pas une raison de retirer MiST de votre script si vous
en avez besoin.

## Pour aller plus loin {#more}

- [Les messages du build](README.md) — les autres familles
- [Scripts personnalisés](../concepts/custom-scripts.md) — déclarer, ordonner, retarder
- [Référence `mission.yaml` — `custom_scripts:`](../../MISSION_YAML_REFERENCE.md#custom-scripts)
