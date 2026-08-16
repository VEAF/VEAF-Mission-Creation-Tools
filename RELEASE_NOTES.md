# VEAF Mission Creation Tools — 6.14.2

Aucune fonctionnalité nouvelle dans cette version : **rien que des choses élémentaires qui ne
marchaient pas**. Une mission construite par les outils n'avait pas de menu CTLD, et un slot posé au
parking ne pouvait pas être pris — le pilote restait spectateur. Neuf défauts distincts, tous
remontés en tirant sur le fil d'un seul rapport : *« pas de menu CTLD sur une mission en 6.14 »*.

Le point commun de ces neuf défauts vaut d'être dit : **aucun ne produisait d'erreur visible**. Le
build était silencieux, `validate` répondait « aucun problème détecté », et la mission se chargeait
sans se plaindre. Il fallait voler pour s'en apercevoir.

---

## ⚠️ À faire en mettant à jour

**Reconstruisez vos missions.** Une mission construite avec 6.14.0 ou avant ne démarre pas CTLD :
pas de menu radio, et le premier `-fob` provoque une erreur de script. Un `veaf-tools mission build`
suffit. Si vous ne pouvez pas reconstruire tout de suite, ajoutez cette ligne à votre
`src/scripts/mission-script.lua` :

```lua
if ctld then veaf.ctld_initialize() end
```

**Recopiez le hook de debug, si vous l'utilisez.** `dcs-fiddle-server.lua` doit être recopié à la
main dans `%USERPROFILE%\Saved Games\DCS\Scripts\Hooks\` — aucun pipeline ne le fait. L'ancienne
version écrase le framework VEAF en pleine mission. Ne concerne que les postes où ce hook est
installé.

**Deux changements de comportement**, sans action de votre part :

- le `.miz` embarque désormais la table des aérodromes du théâtre (~150 Ko de plus sur la Syrie) —
  c'est ce que fait l'éditeur DCS, et c'est ce qui rend les aérodromes utilisables ;
- le **démarrage à chaud** est proposé par défaut sur les aérodromes d'une coalition ;
  `hot_start: false` dans `warehouses.yaml` revient aux démarrages à froid uniquement.

---

## CTLD démarre enfin — et parle votre langue

**CTLD n'était démarré dans aucune mission construite par les outils.** Depuis l'intégration de
CTLD 2, le framework l'*enregistrait* comme module au lieu de le lancer, et l'appel qui devait s'en
charger n'était écrit nulle part. Conséquences : pas de menu CTLD, et un plantage dès qu'une
commande touchait CTLD — un `-fob` mourait sur une erreur d'arithmétique au fond d'un script de 1,1 Mo,
sans que rien ne nomme la cause.

**CTLD parle maintenant la langue de la mission.** Il était figé en anglais quelle que soit la valeur
de `mission.language` — un menu VEAF en français à côté d'un menu CTLD en anglais. Votre réglage
explicite `i18n_lang:` dans `ctld-config.yaml` reste prioritaire, et une langue que CTLD ne connaît
pas (il fournit `en`, `fr`, `es`, `ko`) laisse le moteur dans la sienne.

**Et quand CTLD n'est pas utilisable, il le dit.** Les neuf endroits où VEAF appelle CTLD refusent
désormais avec un message qui nomme le problème et la marche à suivre, au lieu de planter dans le
moteur.

---

## Les slots au parking fonctionnent

Un appareil placé sur une aire de stationnement apparaissait bien dans la liste, se laissait
sélectionner, et **ne se prenait jamais** : le pilote restait spectateur. Un départ en vol, lui,
fonctionnait — ce qui a longtemps masqué le défaut.

La cause : un `.miz` conserve la coalition et les stocks de chaque aérodrome dans une table à part,
une entrée par aérodrome du théâtre. Les missions construites par les outils avaient cette table
**vide**. Sans entrée, l'aérodrome n'existe pas comme base utilisable, et DCS n'a nulle part où
asseoir le pilote. Ouvrir la mission dans l'éditeur DCS puis la sauver réparait le fichier — d'où le
symptôme déroutant : *« ça marche quand je lance depuis l'éditeur »*.

Le build écrit maintenant ces entrées lui-même. Une mission qui déclare déjà ses aérodromes garde les
siens ; ceux qui manquent sont ajoutés.

Deux corrections liées, du même chantier :

- **assigner un aérodrome à une coalition ne désactive plus tous les autres.** Le remplissage ne se
  faisait que sur une table entièrement vide, si bien qu'un seul aérodrome déclaré suffisait à
  laisser les 224 autres inutilisables ;
- **un aérodrome assigné est complet.** Une entrée pouvait exister sans être exploitable — cinq
  champs sur les vingt attendus. Elle est complétée sans écraser ce que la mission a posé.

---

## Slots dynamiques

Les slots dynamiques d'un aérodrome de coalition sont activés par défaut, avec leur catalogue
d'appareils et **le démarrage moteurs tournants**. Ce dernier était systématiquement grisé : le
champ que DCS écrit à `false` n'était jamais remis à `true`.

**Une chose à savoir sur les modèles fournis** : quand un pilote prend un slot dynamique, DCS lui
donne l'appareil *tel que le modèle le décrit* — emport, livrée, fréquences. Or sur les 52 modèles
livrés par défaut, **9 seulement ont un emport**. Un A-10C II ou un F-14B sortent armés et peints ;
un UH-1H, un F/A-18C ou un M-2000C sortent nus. Ce n'est pas un défaut de la chaîne, qui fonctionne :
c'est le modèle qui est vide.

Pour équiper vos slots dynamiques, configurez les appareils **une fois** dans une mission avec
l'éditeur DCS, puis régénérez le fichier depuis elle :

```powershell
veaf-tools.exe content extract-aircraft-groups ma-mission.miz --kind dynamic-template
```

Le guide du créateur de missions détaille la manœuvre.

---

## Outillage

**Les hélicoptères créés par l'assistant sont pilotables.** Toute machine créée par le serveur MCP
était rangée dans la catégorie « avion » — l'éditeur DCS affichait son type en rouge et le slot était
injouable. La catégorie est déduite du type d'appareil ; un type inconnu (mod tiers) est signalé au
lieu d'être deviné en silence.

**`set_airbase_coalition` écrit vraiment.** L'action annonçait un succès et ne modifiait rien : la
coalition d'un aérodrome vit dans une table que la sauvegarde n'écrivait pas.

**Le hook de debug ne décapite plus le framework.** `dcs-fiddle-server.lua` déclarait une variable
globale portant le même nom que la table du framework VEAF, et il s'injecte dans le même
environnement Lua *après* le chargement des scripts. Trente-trois millisecondes après son démarrage,
tout VEAF était hors service pour le reste de la mission.

---

## Merci

À **Tripack**, dont le rapport « pas de menu CTLD » a servi de fil à toute cette série : sans son
`dcs.log`, le défaut serait resté invisible.

À **David**, pour les essais en vol. Rien de tout cela n'était vérifiable sans DCS : trois pistes de
diagnostic ont été éliminées par ses tests avant que la bonne n'apparaisse, et chaque correctif de
cette version a été confirmé en jeu avant d'être livré.

Le plantage constaté au fond de CTLD est remonté chez ses auteurs :
[VEAF/CTLD#125](https://github.com/VEAF/CTLD/issues/125).
