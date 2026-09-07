# DCS se comporte mal — lire son journal

Vous n'arrivez pas à charger une mission. Le jeu se fige au bout de dix minutes. Un module refuse de
démarrer, un menu VEAF n'apparaît pas, une commande ne fait rien. DCS a tout écrit quelque part —
mais le fichier fait 10 Mo et personne ne peut le lire.

`veaf-logs` est fait pour ça. Il ouvre ce fichier, n'en montre que ce qui compte, et **explique** ce
qu'il reconnaît.

!!! info "Ce qu'il fait, et ce qu'il ne fait pas"
    Il **explique**. Il ne répare rien, ne modifie ni votre installation ni vos missions, et il ne
    connaît pas tout : hors de son catalogue, il dit *motif non catalogué* plutôt que d'inventer une
    cause. Une cause fausse mais crédible vous coûterait votre soirée.

## En trois minutes {#quickstart}

Vous n'avez jamais tapé une ligne de commande : ce n'est pas grave, il y en a une seule.

1. **Téléchargez** l'archive des outils VEAF depuis la
   [page des releases](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases), et
   décompressez-la où vous voulez.
2. **Ouvrez le dossier** obtenu dans l'explorateur Windows, puis tapez `powershell` dans la barre
   d'adresse et validez : une fenêtre bleue s'ouvre, déjà placée dans ce dossier.
3. **Tapez** :

    ```powershell
    .\veaf-logs.exe
    ```

    Une fenêtre s'ouvre sur votre `dcs.log` courant. Vous pouvez aussi glisser un fichier de journal
    sur `veaf-logs.exe` directement, sans passer par la ligne de commande.

!!! note "Pourquoi `.\` devant le nom"
    PowerShell — l'invite de commandes par défaut de Windows — ne cherche **pas** les programmes dans
    le dossier courant. Sans le `.\`, il répond que la commande n'existe pas, alors que le fichier
    est visiblement là. C'est l'erreur la plus déroutante qu'on puisse rencontrer. Dans `cmd.exe`, le
    `.\` est facultatif mais accepté : c'est donc la forme à écrire partout.

## Ne garder que ce qui compte {#filter}

Dans la liste déroulante en haut, choisissez le profil **Diagnostic**. Il ne garde que les erreurs et
les avertissements, avec quelques lignes autour pour les expliquer. Sur un journal de session
ordinaire, cela ramène couramment 400 lignes graves à une trentaine.

Si vous cherchez quelque chose de précis — le nom de votre appareil, celui d'un script, un mot vu
dans un message d'erreur — tapez-le dans le champ de recherche.

## Demander une explication {#explain}

Menu **Analyse → Expliquer ce qui est affiché**, ou `Ctrl+E`.

La fenêtre qui s'ouvre répond en deux temps, et la distinction est faite exprès :

- **Catalogue vérifié** — des explications écrites et relues par quelqu'un, reprises telles quelles.
  Elles ne coûtent rien, ne demandent pas Internet, et sont fiables.
- **Mise en contexte par le modèle** — facultative, derrière le bouton **Analyser en ligne**. Elle
  enchaîne les indices : ce qui s'est passé en premier, ce qui n'en est qu'une conséquence, la ligne
  sur laquelle agir. C'est du texte **généré**, à vérifier.

Sans Internet, la première moitié suffit et rien n'affiche d'erreur. C'est un mode de fonctionnement
normal, pas une panne.

!!! warning "Ce qui part de votre machine"
    Rien, tant que vous n'appuyez pas sur **Analyser en ligne**. À ce moment-là part l'extrait que
    vous avez sous les yeux, borné et **caviardé** : votre nom de compte Windows y est remplacé par
    `<user>`, les adresses IP par `<ip>`, les jetons par `<redacted>`. Les noms de vos missions, de
    vos appareils et de vos armements sont conservés — ce sont eux qui disent *sur quoi* ça a planté.

## Préparer un signalement {#report}

Le bouton **Préparer un rapport**, dans la même fenêtre, met dans le presse-papier un bloc qui
contient d'un coup : la description de votre machine et de votre installation, l'extrait du journal,
et ce que l'analyse a conclu — y compris ce qu'elle n'a pas su expliquer.

Collez-le sur le [Discord VEAF](https://www.veaf.org/discord), canal `#support`. Rien n'est envoyé
tout seul : c'est vous qui décidez où le coller, et le bloc est du texte, vous pouvez le relire.

Il est taillé pour tenir dans un message Discord. Quand tout ne rentre pas, il le dit et nomme ce qui
a été retiré, plutôt que d'être coupé en silence au milieu d'une ligne.

## Et ensuite {#next}

- [Obtenir de l'aide](../SUPPORT.md) — où signaler, et quoi fournir
- [`veaf-logs` en détail](../mission-maker/LOGS.md) — filtres, recherche, profils, gros journaux
- [Guide du pilote](GUIDE.md) — tout ce qui se fait en jeu
