# veaf-logs — lire les journaux de DCS

`veaf-logs` ouvre un journal DCS et n'en montre que ce qui compte. Il connaît les
scripts VEAF, CTLD, CSAR, AIEN et Skynet, sait reconnaître les erreurs d'Eagle
Dynamics sans conséquence, et suit le fichier en direct pendant que la mission
tourne.

## Lancer

Depuis l'exécutable téléchargé avec la release :

```
.\veaf-logs.exe
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
**Contexte des catégories** réglée en haut du panneau.

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

### Lignes de contexte {#search-context}

Un résultat seul ne dit pas grand-chose : c'est souvent ce qui l'entoure qui
explique. **Contexte de recherche**, dans le panneau latéral, garde ±N lignes de
part et d'autre de chaque résultat, comme le `-C` de `grep`. Il vaut 0 par
défaut : tant qu'on n'y touche pas, une recherche rend exactement ses lignes.

Le champ `±` de la barre de recherche donne une portée propre à un critère ;
laissé vide, il suit la valeur commune. Quand plusieurs critères sont actifs,
c'est la portée la plus large qui s'applique. Un critère inversé (`≠`) n'a pas de
résultat à entourer et n'entre pas dans le calcul.

**Les filtres restent prioritaires.** Une ligne masquée par son niveau, sa source
ou sa famille de bruit le reste, même collée à un résultat : le contexte élargit
la recherche, il ne défait pas un filtre. Chercher `ERROR` avec ±2 en ayant mis
`INFO` à ✕ ne fait pas revenir les `INFO` voisines.

Les deux contextes se composent : une catégorie en ◐ apparaît autour d'un
résultat de recherche selon **sa** portée à elle.

## Lire une ligne en entier

**Le détail, sous la table.** Cliquer une ligne — n'importe laquelle, pas
seulement une erreur — l'affiche en entier en dessous, trace de pile comprise. La
séparation se tire à la souris, et `Ctrl+I` referme le panneau quand on veut
toute la hauteur pour la table.

**L'ascenseur horizontal.** La colonne Message est dimensionnée sur le plus long
message du journal : une ligne qui dépasse la fenêtre se lit en défilant vers la
droite. Tirer la colonne à la main fige la largeur choisie ; changer de police
rend la main.

**La taille du texte.** Les boutons `A−` / `A+` en haut à droite, `Ctrl++` /
`Ctrl+-`, ou `Ctrl`+molette sur la table. `Ctrl+0` revient à la taille d'origine
et **Affichage → Police…** choisit une autre police à chasse fixe. Le choix vaut
pour tous les onglets et se retrouve à la session suivante.

## Copier

| | |
|---|---|
| Un bloc de lignes | les sélectionner dans la table (`Maj`+clic, `Ctrl`+clic), puis `Ctrl+C` |
| Une partie d'une ligne | la sélectionner au caractère dans le panneau de détail, puis `Ctrl+C` |

Une ligne copiée emporte sa trace de pile : coller un `Mission script error` sans
elle donnerait une erreur que rien n'explique. Le clic droit propose en plus de
copier le message **sans l'en-tête DCS**, quand on ne veut ni l'horodatage ni le
sous-système.

## Expliquer ce qui est affiché {#explain}

**Analyse → Expliquer ce qui est affiché**, ou `Ctrl+E`. La réponse arrive en
deux couches, séparées à l'écran, et l'ordre entre elles est tout le sujet.

**Le catalogue répond en premier.** Chaque motif reconnu par `rules.json` est
rendu avec son propre texte, repris tel quel. Aucun modèle, aucun coût, aucun
réseau : cette couche seule est déjà une réponse, et c'est le mode dégradé du
reste.

**Le modèle met en contexte ensuite**, seulement si on appuie sur **Analyser en
ligne**. Il reçoit l'extrait et les motifs déjà appariés localement, et il
enchaîne : ce qui s'est passé en premier, ce qui n'en est qu'une conséquence, la
ligne sur laquelle agir. Là où le catalogue est muet, il dit *motif non
catalogué* au lieu de proposer une cause.

Le pire échec de cette fonction n'est pas le silence, c'est une réponse
plausible et fausse : *« ça vient de votre module X »* alors que non. Le lecteur
n'a aucun moyen de la distinguer d'une bonne, et il y passera sa soirée. C'est
pourquoi les deux couches sont titrées séparément plutôt que suivies d'un
avertissement en bas, que personne ne lit.

Sans réseau, sans quota, derrière un proxy d'entreprise : la couche catalogue
répond et aucune boîte d'erreur n'apparaît.

### Ce qui part de la machine {#explain-privacy}

Rien, tant qu'on n'a pas appuyé sur **Analyser en ligne**. À ce moment-là part
l'extrait affiché, **borné** (une limite en caractères, les omissions annoncées)
et **caviardé** par le même code que `veaf-tools doctor` : nom de compte Windows
→ `<user>`, adresses IP → `<ip>`, adresses e-mail → `<email>`, jetons et mots de
passe → `<redacted>`. Les noms de missions, d'appareils et d'armements sont
conservés : ce sont eux qui disent *sur quoi* ça a planté.

L'en-tête de l'extrait déclare aussi les catégories mises à ✕. Un journal filtré
jusqu'à « aucune erreur » parce qu'on a décoché `ERROR` ne doit pas se lire comme
un journal propre.

### Motifs récurrents non catalogués {#proposals}

Un message qui revient et que `rules.json` n'explique pas est une **entrée
manquante** du catalogue. L'analyse en propose une, dans la forme du fichier,
identifiants et valeurs variables déjà remplacés par des jokers.

Rien n'est écrit dans `rules.json` : une proposition reste une proposition, et
c'est précisément parce que le catalogue est tenu à la main que son texte est
citable. Le `help` généré n'explique volontairement rien, il dit qu'il est à
reformuler.

## Préparer un rapport {#report}

Le bouton **Préparer un rapport** assemble en un bloc la sortie de
`veaf-tools doctor`, l'extrait borné et caviardé, les motifs du catalogue et ce
que l'analyse a conclu — y compris ce qu'elle n'a pas su expliquer — et le met
dans le presse-papier, prêt à coller dans `#support` ou dans une issue.

C'est un **collage**, pas un envoi : rien ne part tout seul. Le bloc est taillé
pour tenir dans un message Discord ; quand tout ne rentre pas, il annonce ce
qu'il a retiré au lieu d'être coupé en silence.

Son format est versionné et documenté : voir
[Format du bloc de rapport](../developer/report-block.md).

## Ce qu'il comprend du journal

**Les traces de pile restent avec leur erreur.** Un `Mission script error` suivi
de son `stack traceback` forme une seule entrée : filtrer sur les erreurs ne fait
plus disparaître l'explication. La ligne porte alors un `[+3]` qui dit combien de
lignes sont repliées derrière elle.

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
| `Ctrl+C` | copier la sélection |
| `Ctrl+Maj+C` | copier sans l'en-tête DCS |
| `Ctrl+A` | tout sélectionner |
| `F` | suivre la fin du fichier / mettre en pause |
| `Ctrl+R` | tout afficher |
| `Ctrl+S` | enregistrer le profil |
| `Ctrl++` / `Ctrl+-` | agrandir / réduire la police |
| `Ctrl+0` | taille de police par défaut |
| `Ctrl`+molette | agrandir / réduire la police |
| `Ctrl+I` | afficher ou masquer le panneau de détail |
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
| Session (fichiers ouverts, filtres, géométrie, police) | `%APPDATA%\veaf-logs\session.json` |
| Profils | `%APPDATA%\veaf-logs\profiles.json` |
