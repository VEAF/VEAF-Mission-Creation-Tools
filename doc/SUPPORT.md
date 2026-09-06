# Obtenir de l'aide

Quelque chose ne marche pas. Cette page dit **où le signaler** et **quoi fournir** pour que
quelqu'un puisse vous répondre autre chose que « quelle version ? ».

## Où s'adresser {#where}

| Votre situation | Le bon endroit |
|---|---|
| Une question, un doute, « est-ce que c'est normal ? » | [Discord VEAF](https://www.veaf.org/discord), canal `#support` |
| Quelque chose ne fonctionne pas comme annoncé | [une issue GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/new/choose) |
| Une idée, un manque | [une issue GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/new/choose), formulaire « feature request » |
| Une faille de sécurité | **pas d'issue publique** — voir [ci-dessous](#security) |

Le Discord est le plus rapide pour une question ; l'issue est le seul endroit où un défaut ne se
perd pas. En cas de doute, demandez sur le Discord : quelqu'un vous dira s'il faut ouvrir une issue.

## L'assistant de documentation {#assistant}

Le bouton en bas à droite de ces pages ouvre un assistant qui répond à partir de la documentation.
Il tourne sur une **allocation gratuite, partagée par tous les visiteurs du site** : un jour chargé,
elle peut s'épuiser. L'assistant vous le dira alors, et vous dira quand il revient — l'allocation
repart le matin suivant.

Ce n'est pas une panne, et rien n'est perdu entre-temps : la documentation reste consultable, le
Discord et les issues aussi. La commande [`veaf-tools ask`](CLI_REFERENCE.md#ask) interroge le même
assistant, donc la même allocation.

## Demander au bot : `/ask` {#ask}

Sur le Discord VEAF, la commande `/ask` répond aux questions **sur la documentation**.

```text
/ask question: comment ajouter un préréglage radio à une mission ?
```

Le bot ouvre un **fil public** sous votre question et y écrit sa réponse au fur et à mesure, avec
les liens vers les pages qu'il a utilisées.

Le fil est public exprès : la réponse sert à la personne suivante qui posera la même question, et
n'importe qui peut y passer pour corriger le bot — « non, depuis la 6.19 ça marche autrement ». Sur
un assistant de documentation, c'est la seule correction qui rattrape vraiment une réponse fausse.

### Ce qu'il faut savoir avant de s'y fier

- **Il répond à partir de la documentation, et de rien d'autre.** Il ne lit pas le code, ne regarde
  pas votre mission, n'ouvre pas votre journal. Si la documentation ne couvre pas le sujet, il le
  dit et vous renvoie vers cette page — c'est une réponse, pas une panne.
- **Il peut se tromper, ou être en retard d'une version.** Vérifiez sur les pages qu'il cite ; c'est
  pour ça qu'il les cite. Si la réponse est fausse, dites-le dans le fil : les gens autour la
  liront.
- **Une lacune de la documentation devient une réponse fausse ou absente.** Le correctif est
  d'écrire la page, pas de régler le bot. Une question à laquelle il ne sait pas répondre est donc
  utile : signalez-la, elle vaut un ticket de documentation.
- **Il y a des quotas.** Quelques questions par minute et par personne, une limite par jour, et une
  limite pour tout le serveur — elles protègent le quota gratuit que partagent aussi le site et la
  ligne de commande. S'il refuse, il vous dit pourquoi et à quelle heure ça repart.

### Ce qu'il ne fait **pas**

Il ne lit pas les sources et ne regarde pas votre mission. En revanche, si sa réponse ne règle pas
votre problème, le bouton **« Signaler un bug »** sous la réponse ouvre le formulaire de
[`/bug`](#bug) avec votre question et sa réponse déjà dedans.

!!! tip "La même chose hors du Discord"
    `.\veaf-tools.exe ask` pose les mêmes questions au même assistant, depuis votre machine. Voir
    la [Référence CLI](CLI_REFERENCE.md).

## Signaler un bug depuis Discord : `/bug` {#bug}

Sur le Discord VEAF, `/bug` ouvre un **formulaire** : ce qui s'est passé, ce que vous attendiez, les
étapes, et le bloc [`veaf-tools doctor`](#doctor). Vous pouvez y joindre un journal, une mission,
un fichier de configuration.

**Vous n'avez pas besoin d'un compte GitHub.** Le ticket est ouvert par un robot, en votre nom :
votre pseudo Discord y est cité comme rapporteur, et rien d'autre de votre identité.

### Ce que le bot fait de votre formulaire

Tout ce qui suit se fait **sans intelligence artificielle** — ce sont des lectures et des recherches,
donc c'est exact, et ça marche même quand tout le reste est en panne :

- il lit le bloc `doctor` pour en tirer la version, celle de DCS, le système ;
- si votre message ou votre journal contient une erreur, il en extrait le **fichier et la ligne**,
  puis va lire le code autour dans le dépôt ;
- il réduit un journal de 11 Mo à l'extrait qui compte, avec ce que son catalogue y reconnaît ;
- il résume la mission jointe — théâtre, date, météo, nombre de groupes — sans publier son contenu ;
- il compare votre problème aux tickets ouverts, aux tickets récemment fermés, aux chantiers en
  cours et à la feuille de route. **Si c'est déjà corrigé, il vous le dit et n'ouvre rien** : c'est
  le meilleur résultat possible, vous êtes débloqué tout de suite.

### Rien n'est publié avant votre clic

Le bot vous montre le ticket **tel qu'il partira**, puis attend. Trois boutons : **déposer**,
**corriger** (le formulaire revient avec vos réponses), **annuler**. Si vous ne cliquez pas,
l'aperçu expire au bout de huit minutes et rien n'est déposé.

C'est important parce que vous avez tapé trois champs et qu'une vingtaine de lignes vont être
publiées : l'extrait de journal, le code, votre environnement. Le clic est le moment où vous voyez
la différence et où vous pouvez dire *non, pas ça*.

**Vos données personnelles sont retirées avant publication** : chemins de votre disque, adresses,
identifiants. Si le filtrage ne peut pas s'exécuter, **rien n'est publié** — jamais de repli sur le
texte brut. Un cas échappe à ce filtre : ce que vous tapez vous-même. Si vous écrivez votre nom
dans « ce qui s'est passé », ou si votre mission s'appelle `mission de Jean Dupont.miz`, il sera
publié.

### Ce qui se passe ensuite

Le bot ouvre un **fil public** et y met le lien du ticket. Quand quelqu'un répond sur le ticket, ou
quand il est fermé, **le bot le rapporte dans ce fil** : vous n'avez pas à surveiller GitHub.

Dans l'autre sens, c'est **manuel** : pour ajouter quelque chose — un fichier oublié, une précision —
écrivez-le dans le fil, un mainteneur le reportera sur le ticket. Le bot n'écrit pas de Discord vers
GitHub, et c'est délibéré : ça ouvrirait une porte d'écriture sur un dépôt public depuis un salon
où n'importe qui peut entrer.

### L'hypothèse automatique

Sur les tickets déposés par un **membre VEAF**, et tant que l'allocation du jour n'est pas épuisée,
un modèle ajoute une **hypothèse** sur la cause : un commentaire séparé, signalé comme une
supposition de machine, avec le fichier et la ligne suspectés.

Ce n'est pas un diagnostic, et **son absence n'enlève rien à votre signalement** : le reste du
ticket est mesuré, cité ou analysé, jamais deviné. Quand elle manque, le ticket dit pourquoi.

## Proposer une amélioration : `/suggest` {#suggest}

Sur le Discord VEAF, `/suggest` sert à demander **ce qui n'existe pas encore** — une fonctionnalité,
un réglage, une commande. Comme pour `/bug`, vous n'avez pas besoin d'un compte GitHub.

### Il commence par regarder si ça existe déjà

C'est le point de la commande. Une bonne partie des demandes portent sur quelque chose qui **existe
déjà** et que personne n'a trouvé : dans ce cas, la meilleure réponse est la page qui l'explique,
tout de suite, plutôt qu'un ticket qui attendra des mois.

Le bot vérifie donc, dans cet ordre :

1. **la documentation** — il pose votre demande à l'assistant, qui répond avec les pages
   correspondantes. Si ça répond à votre besoin, vous le dites et **rien n'est ouvert** ;
2. **les tickets ouverts** — quelqu'un l'a peut-être déjà demandé ;
3. **les chantiers en cours et la feuille de route** — c'est peut-être déjà prévu, ou explicitement
   écarté, avec les raisons.

À chaque fois, le bot vous montre **ce qu'il a trouvé et pourquoi**, et vous pouvez répondre *non,
ce n'est pas ça* : votre demande continue son chemin. Une machine ne décide pas à votre place que
votre idée existe déjà.

Si la documentation ne dit rien du sujet, le ticket le note. C'est utile : si la fonctionnalité
existe en réalité, ce n'est pas une demande d'évolution, c'est une **page à écrire** — et c'est le
correctif le moins cher qui soit.

### Ce qu'il vous demande, et pourquoi

Le formulaire demande d'abord **quel problème vous cherchez à résoudre**, avant la solution que vous
imaginez. C'est le champ que tout le monde saute, et c'est celui qui rend une demande décidable :
une solution sans problème ne peut être ni comparée à autre chose, ni obtenue autrement, ni refusée
pour une raison qu'on puisse énoncer.

Le bot n'écrit **aucune ébauche technique**. Il énonce votre besoin et ce qui a été vérifié ; où ça
se brancherait et ce que ça toucherait, c'est le travail de qui prendra le sujet.

### Rien n'est publié avant votre clic

Comme pour `/bug` : le ticket vous est montré tel qu'il partira, avec trois boutons — **déposer**,
**corriger**, **annuler**. Sans clic, rien n'est déposé. Ensuite, le bot ouvre un fil public et y
rapporte ce qui se passe sur le ticket.

### Ce qu'un ticket veut dire, et ce qu'il ne veut pas dire

À dire franchement, parce que c'est ce qui déçoit quand on ne l'a pas lu avant : **un ticket est un
enregistrement, pas un engagement.** Un bug est vrai ou faux et se vérifie ; une évolution est
seulement souhaitée ou non, et c'est le mainteneur du projet qui tranche, seul.

Un ticket d'évolution a donc [deux avenirs possibles](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/CONTRIBUTING.md) :
il est repris dans un chantier, ou il reste ouvert comme un témoignage. Le second n'est pas un
échec : il enregistre que quelqu'un en a eu besoin, et le troisième qui le demandera pèsera plus
lourd que le premier.

## Ce qu'il faut fournir {#what-to-provide}

Les signalements utiles se ressemblent tous. Trois choses, dans cet ordre :

1. **Ce que vous avez fait, ce que vous attendiez, ce qui s'est passé.** Trois phrases suffisent, à
   condition qu'elles soient concrètes : « j'ai lancé `.\veaf-tools.exe build`, j'attendais un
   `.miz`, j'ai eu une erreur rouge ».
2. **Le bloc de `doctor`** (ci-dessous). Il contient les versions et les chemins — c'est
   exactement ce qui manque presque toujours.
3. **Les fichiers**, si vous les avez : le journal DCS, la mission, une capture d'écran.

## Lancer `doctor` {#doctor}

Depuis le dossier où se trouve l'exécutable :

```powershell
.\veaf-tools.exe doctor
```

!!! note "Pourquoi `.\`"
    PowerShell — l'invite de commandes par défaut de Windows — ne cherche **pas** les programmes
    dans le dossier courant. Sans le `.\`, il répond que la commande n'existe pas, alors que le
    fichier est là. Dans `cmd.exe`, le `.\` est facultatif mais accepté : c'est donc la forme à
    écrire partout.

La commande affiche d'abord un tableau lisible, puis un bloc encadré par
`=== VEAF-TOOLS DOCTOR BEGIN ===`. **C'est ce bloc qu'il faut copier** dans votre message Discord
ou votre issue, tel quel.

Il est conçu pour être publié : votre nom de compte Windows y est remplacé par `<user>` partout où
il apparaît, les adresses IP par `<ip>`, les adresses e-mail par `<email>`, et les mots de passe et
jetons par `<redacted>`.

En revanche, les **noms de vos missions, de vos appareils et de vos armements sont conservés** : ce
sont eux qui disent *sur quoi* ça a planté, et les masquer reviendrait à envoyer un rapport qui dit
seulement « ça n'a pas marché ». Si l'un de ces noms vous paraît sensible, jetez un œil au bloc avant
de le coller — c'est du texte, vous pouvez le modifier.

Pour n'obtenir que le bloc, sans le tableau :

```powershell
.\veaf-tools.exe doctor --paste
```

## Où sont les journaux {#logs}

Il y en a deux, et ils ne disent pas la même chose.

| Journal | Où | Ce qu'il contient |
|---|---|---|
| Journal de l'outil | `%USERPROFILE%\.veaf\veaf-tools.log` | ce que `veaf-tools.exe` a fait sur votre machine : conversion, build, injection, et la trace complète des erreurs |
| Journal de DCS | `%USERPROFILE%\Saved Games\DCS\Logs\dcs.log` | ce qui s'est passé **en jeu** : chargement des scripts, erreurs Lua, comportement des modules VEAF |

Si vous avez défini la variable d'environnement `VEAF_HOME`, le journal de l'outil est écrit là
plutôt que dans `.veaf`. Le tableau de `doctor` en donne le chemin exact — c'est la réponse la plus
sûre, elle vient de la machine.

Le journal de l'outil est **tronqué automatiquement** : il roule à 2 Mo, et trois fichiers plus
anciens sont conservés à côté (`veaf-tools.log.1`, `.2`, `.3`). `doctor` va chercher les erreurs
récentes dans ces fichiers-là aussi : juste après un roulement, le journal vivant est presque vide
et tout l'historique se trouve dans `.1`.

Pour le journal de DCS, [`veaf-logs`](mission-maker/LOGS.md) l'ouvre et n'en montre que ce qui
compte ; le fichier brut fait souvent plus de 10 Mo, ce qui n'est ni lisible ni envoyable tel quel.

## Quand c'est DCS qui ne va pas {#dcs-trouble}

Si le problème est en jeu — une mission qui ne charge pas, un module qui refuse de démarrer, un menu
VEAF absent — `veaf-logs` sait aussi **expliquer** ce qu'il lit, et préparer un bloc de signalement
tout fait. Voir [DCS se comporte mal](pilot/dcs-trouble.md), écrit pour quelqu'un qui n'a jamais
lancé une commande VEAF.

## Signaler une faille de sécurité {#security}

**N'ouvrez pas d'issue publique.** Utilisez
[le signalement privé de GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools/security/advisories/new),
qui garde le rapport confidentiel jusqu'à la publication d'un correctif. La politique complète est
dans [`SECURITY.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/SECURITY.md).

## Pour aller plus loin

- [Référence CLI](CLI_REFERENCE.md) — toutes les commandes et leurs options
- [Mise à jour & publication](TOOLS_REFERENCE.md) — dépannage de `veaf-tools-updater.exe`
- [Lire les journaux de DCS](mission-maker/LOGS.md) — l'outil `veaf-logs`
