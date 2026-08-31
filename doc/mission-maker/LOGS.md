# veaf-logs — lire les journaux de DCS

`veaf-logs` ouvre un journal DCS et n'en montre que ce qui compte. Il connaît les
scripts VEAF, CTLD, CSAR, AIEN et Skynet, sait reconnaître les erreurs d'Eagle
Dynamics sans conséquence, et suit le fichier en direct pendant que la mission
tourne.

## Lancer

Depuis l'exécutable téléchargé avec la release :

```
veaf-logs.exe
```

Sans argument, il rouvre les fichiers de la dernière session ; à défaut, le
`dcs.log` courant (`Saved Games\DCS\Logs\dcs.log`). On peut aussi lui passer un
chemin, ou faire glisser un fichier dessus.

Depuis les sources :

```
poetry install --all-extras
poetry run veaf-logs
```

L'interface graphique demande PySide6, déclaré en dépendance optionnelle
(`--all-extras`, ou `--extras logs`). Le reste de `veaf-tools` n'en a pas besoin.

## Les trois états

Chaque niveau, chaque source et chaque famille de bruit se règle d'un clic, en
faisant défiler trois états :

| | |
|---|---|
| ✓ | affiché |
| ◐ | **contexte** — affiché seulement autour d'une ligne retenue |
| ✕ | masqué |

Le mode contexte est ce qui rend un journal lisible. Mettre `INFO` en ◐ avec
±3 lignes ne garde que les erreurs et les avertissements, entourés de ce qui les
explique. Chaque catégorie peut avoir sa propre portée : le champ `±` apparaît à
sa droite dès qu'elle passe en ◐, et laisser le champ vide reprend la valeur
commune réglée en haut du panneau.

Écarter le bruit ED change l'échelle de ce qu'il reste à lire :

| Journal | Lignes graves | Affichées |
|---|---|---|
| Un `dcs.log` de session | 416 | **34** |
| Ce `dcs.log` et quatre journaux archivés | 2 714 | **278** |

« Lignes graves » : de niveau `ERROR`, `ERROR_ONCE` ou `ALERT`. Un journal grossit
tant que le jeu tourne, donc un relevé fait un autre jour donne quelques lignes
d'écart.

## Profils

La liste déroulante en haut retient un jeu de filtres complet — états des
catégories, critères de recherche, portées du contexte. Trois profils sont
fournis :

- **Tout** — aucun filtre, la porte de sortie quand on s'est perdu ;
- **Lecture** — le bruit ED masqué ;
- **Diagnostic** — erreurs et avertissements, avec trois lignes de contexte.

`Enregistrer…` crée un profil ; les profils fournis ne sont ni modifiables ni
supprimables. Dès qu'un filtre change, la liste repasse sur « Session courante » :
un profil enregistré ne bouge jamais sans qu'on le demande.

## Recherche

Trois modes, au choix dans la liste déroulante :

| Mode | `.` | `*` `?` | Exemple |
|---|---|---|---|
| Texte | littéral | littéraux | `CSAR.lua` |
| Jokers | littéral | jokers | `No taxiroad*Batumi*` |
| Regex | joker | quantificateurs | `VEAF\|[WE]\|` |

`≠` inverse le critère, `Aa` respecte la casse. **Ajouter au filtre** empile le
critère courant : les filtres se cumulent et s'affichent en pastilles retirables
d'un clic.

La recherche porte sur la ligne **et** sur la trace de pile qui la suit :
chercher un symbole présent uniquement dans la trace ramène l'erreur qui l'a
produite.

## Ce qu'il comprend du journal

**Les traces de pile restent avec leur erreur.** Un `Mission script error` suivi
de son `stack traceback` forme une seule entrée : filtrer sur les erreurs ne fait
plus disparaître l'explication. La ligne porte alors un `[+3]`, et le détail
s'affiche en bas quand on la sélectionne.

**Le niveau affiché est le niveau réel.** DCS journalise tout le Lua en
`INFO SCRIPTING`, y compris un `VEAF|W|` qui est un avertissement. `veaf-logs` le
lit dans le préfixe : filtrer sur WARNING fait bien remonter les avertissements
VEAF, CTLD ou CSAR.

**Les archives s'ouvrent directement.** Les `.zip` de `Saved Games\DCS\Logs`
contiennent aussi le vidage mémoire, la mission et le rapport dxdiag : le journal
est choisi tout seul.

**Le journal n'est jamais verrouillé.** Sous Windows, un fichier maintenu ouvert
ne peut pas être renommé — et c'est ce que DCS fait de son `dcs.log` à chaque
lancement. `veaf-logs` ouvre et referme à chaque lecture : il n'empêche jamais le
jeu de démarrer.

## Gros journaux

Le texte n'est pas chargé en mémoire : seul un index compact l'est, et les lignes
sont décodées à l'affichage. Sur un journal de serveur de 119 Mo (991 392 lignes) :

| | |
|---|---|
| Premières lignes lisibles | 0,3 s |
| Indexation complète | 8,6 s, en tâche de fond |
| Mémoire | 37 Mo |
| Recherche | 0,65 s |

L'indexation se poursuit pendant qu'on lit et qu'on filtre ; une barre de
progression apparaît, avec un bouton pour l'interrompre — ce qui est déjà indexé
reste utilisable.

## Raccourcis

| | |
|---|---|
| `Ctrl+D` | ouvrir le `dcs.log` courant |
| `Ctrl+O` | ouvrir un fichier |
| `Ctrl+W` | fermer l'onglet |
| `Ctrl+F` | chercher |
| `F` | suivre la fin du fichier / mettre en pause |
| `Ctrl+R` | tout afficher |
| `Ctrl+S` | enregistrer le profil |
| `F5` | recharger le catalogue de règles |

## Ajouter ses propres règles

Les sources reconnues, les couleurs et les familles de bruit vivent dans un seul
fichier, `veaf_logs/rules.json`, que le menu **Règles** ouvre et recharge (`F5`)
sans quitter l'application.

Un script maison tient en une entrée :

```json
{
  "id": "monscript",
  "label": "MonScript",
  "color": "#ff8800",
  "match": "^MONSCRIPT\\|(?P<lvl>[A-Z])\\|",
  "level_group": "lvl",
  "level_map": {"D": "DEBUG", "I": "INFO", "W": "WARNING", "E": "ERROR"}
}
```

Une famille de bruit à écarter :

```json
{
  "id": "mon_bruit",
  "label": "Libellé court affiché",
  "help": "Phrase d'explication montrée en infobulle.",
  "default_hidden": true,
  "match": "le motif à masquer",
  "regex": true
}
```

Les motifs sont appliqués sur des octets pour que l'indexation reste rapide : ils
doivent rester en ASCII. Le nombre de familles de bruit est plafonné à 64.

## Où sont rangés les réglages

| | |
|---|---|
| Session (fichiers ouverts, filtres, géométrie) | `%APPDATA%\veaf-logs\session.json` |
| Profils | `%APPDATA%\veaf-logs\profiles.json` |
