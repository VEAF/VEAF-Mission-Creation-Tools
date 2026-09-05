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
