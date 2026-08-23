# Message pour Flogas — PR Skynet-IADS

Brouillon à relire avant envoi (Discord, probablement le canal Skynet ou en direct).
`contributing.md` du dépôt demande de passer par Discord **avant** de coder ; la PR est déjà ouverte,
donc le message l'annonce plutôt qu'il ne la propose. Si tu préfères respecter l'ordre à la lettre, je
peux repasser la PR en brouillon le temps de la discussion.

---

## Version courte (si tu veux juste pinguer)

> Salut Flogas ! On a trouvé un bug dans Skynet en creusant des SAM qui lèvent leurs missiles et se
> rétractent sans tirer. C'est dans `evaluateContacts` : un site déjà allumé est exclu de la liste des
> sites à informer, donc son `targetsInRange` reste à false et `targetCycleUpdateEnd` l'éteint au cycle
> suivant — alors que la cible est toujours là. Résultat : allumé/éteint toutes les 5 s.
>
> PR sur votre fork : https://github.com/regroupement-patrouille/Skynet-IADS/pull/4 — une ligne retirée
> plus le test de régression qui manquait. Je n'ai pas pu faire tourner votre suite (elle a besoin de DCS
> avec le .miz de tests), donc à vérifier avant merge — ou je le fais chez nous si ça vous arrange.

---

## Version détaillée

Salut Flogas,

On utilise Skynet dans les missions VEAF, compilé depuis votre fork (`3.4.0RP`, build du 10/09/2025) —
justement parce que vous l'avez fait vivre là où l'amont s'est arrêté en 2023. Merci pour ça, au
passage : les ajouts Tor M2 / Pantsir sont exactement ce qui nous manquait.

En enquêtant sur un comportement bizarre, on est tombé sur ce qui ressemble à un vrai bug, et on vous
propose un correctif.

### Le symptôme

Un SA-6 complet (2× `Kub 1S91 str` + 4× `Kub 2P25 ln`) avec un radar de veille au-dessus : il acquiert,
oriente ses lanceurs, lève ses missiles — puis se remet en position route. Cinq cycles d'affilée, sans
tirer. Le même site sur une carte nue **sans aucun script** engage normalement, ce qui nous a orientés
vers Skynet plutôt que vers DCS.

### La cause

Dans `SkynetIADS.evaluateContacts()`, les sites sous couverture d'un radar de veille ne sont collectés
que s'ils sont **inactifs** :

```lua
-- only if a SAM site is not active we add it to the hash of SAM sites to be iterated later on
if samSiteUnterCoverage:isActive() == false then
    samSitesToTrigger[samSiteUnterCoverage:getDCSName()] = samSiteUnterCoverage
end
```

Or `informOfContact()` est le **seul** endroit qui met `targetsInRange = true`, et
`targetCycleUpdateStart()` le remet à false à **chaque** cycle. Donc un site qui vient de s'allumer est
actif au cycle suivant, il est filtré ici, jamais informé, son drapeau reste false, et
`targetCycleUpdateEnd()` l'éteint — cible toujours présente et à portée.

| Cycle | État au départ | Collecté ? | `targetsInRange` | Fin de cycle |
|---|---|---|---|---|
| N | éteint | oui | `true` | reste allumé |
| N+1 | **allumé** | **non — filtré** | `false` | **s'éteint** |
| N+2 | éteint | oui | `true` | se rallume |

C'est une dégradation, pas une panne : radar éteint la moitié du temps, le site finit parfois par tirer.
C'est probablement pour ça que ça n'a pas été remonté plus tôt.

### Ce qu'on propose

https://github.com/regroupement-patrouille/Skynet-IADS/pull/4

Retirer le filtre. Le coût est d'un appel `isTargetInRange()` par site allumé et par cycle —
`informOfContact()` court-circuite dès que le drapeau est vrai, donc un appel, pas un par contact. Le
reste ne change pas : un site dont la cible est réellement partie s'éteint toujours, puisque rien ne
l'informe.

Plus le test de régression qui manquait. Tous vos tests existants sur ce chemin appellent `goDark()`
avant `informOfContact()`, donc ils exercent la transition **vers** l'allumage ; et
`testEvaluateContacts1EWAnd1SAMSiteWithContactInRange` retire la cible avant son second
`evaluateContacts()`. Rien n'appelle `evaluateContacts()` deux fois avec la cible encore là — c'est
précisément le cas qui casse. Le nouveau test fait ça sur trois cycles, avec les mêmes unités que son
voisin, donc pas besoin de toucher au `.miz`.

### Ce qu'on n'a pas pu faire

**On n'a pas fait tourner votre suite.** Elle a besoin de DCS avec `skynet-unit-tests.miz` chargé, et on
n'a pas de moyen de la lancer sans surveillance. Votre `contributing.md` demande des tests passants, donc
on préfère le dire franchement plutôt que de laisser croire qu'on a vérifié. Ce qu'on a validé : les deux
fichiers parsent en Lua 5.1, et le test n'utilise que des unités dont le test voisin dépend déjà.

Si ça vous arrange, on peut le faire tourner chez nous et vous rendre compte avant que vous mergiez.

On a aussi laissé `demo-missions/skynet-iads-compiled.lua` tel quel plutôt que de le régénérer avec
`build-compiled-script.ps1` — pour que le diff reste lisible, et parce que le numéro de version vous
appartient.

### Un point qu'on n'a pas corrigé

Un site qui détecte la cible **lui-même** n'est pas informé non plus : `evaluateContacts()` fusionne ses
contacts dans l'IADS mais ne lui appelle pas `informOfContact()`, donc il s'éteint aussi si aucun radar
de veille ne voit la cible. C'est un changement distinct, on n'a pas voulu le mélanger — on ouvre une
seconde PR si vous êtes d'accord sur le principe.

À dispo pour en discuter,
David
