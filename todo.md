# This file contains all the ideas for new features and requests for change or correction that we receive

## List

### Idea - needs investigation

- add a Missile Training module that can work with a zone or a radio menu
- add an AWACS module ; see notes about that lower
- find a way to get the data about coordinates in the Scratchpad mod; it works solo, maybe we can make it work multi with the help of SlMod ?
- add a function to help find a town location
- make a module that decorate a ship (statics spawn, SSW escort by subs, helos and S3s, speed and drift DDs)
- move the bullseye
- _destroy could delete the named points
- add JTACs to the DCS Jtac menu
- find a way to spawn convoys on the road to speed up convoy setup
- progression en liant les combatzones l'une après l'autre
- menu radio de contrôle des QRA
  - activation/désactivation
  - informations (état, dessin des zones, groupes actifs)
  - changement de mode (training: il faut sortir de la zone pour réarmer la QRA; mission: plusieurs groupes se succèdent de loin avant de devoir réarmer la QRA)
- move AWACS comme TANKER

### RFC - needs to be done

- bouger les escortes avec les tankers
- gérer la sécurité en venant d'une commande chat pour _tous_ les modules (fait uniquement pour shortcuts)

### Bug - needs to be corrected

bug -armor avec sa9 , "patrol, dest, offroad" ne bougent pas
## Notes

### add an AWACS module

- like EWRS but better

  - no more chat spamming
  - manage an on-demand picture or bogey dope like the vanilla awacs
  - make the picture clearer and more realistic (see with Couby :
  > Ce qui serait bien dans ce nouveau GCI/AIC automate, c'est qu'il donne une picture dans une zone d'intérêt par rapport au demandeur, et qu'il ajuste la taille de cette zone considérée en fonction de la densité de la picture résultante.
  > Ce qui serait bien aussi c'est de pouvoir paramétrer la notion de threat calls : quand il va donner des informations en BRAA.
  > Et le top, qu'il sache ajuster le contenu en fonction de critères de dangerosité...
  
### NIOD

  https://discordapp.com/channels/471061487662792715/570716657069064210/735503835954675762

@[VEAF]Zip#2423 Pour info je viens de delete le package niod de npm. Il s'appelle maintenant https://www.npmjs.com/package/niod-core , le versioning étaient un peu crade donc je suis repartis de 0. Pour vous il faut donc `npm i niod-core@v0.1.0-beta.3` et `npm uninstall niod`
Ensuite dans le code ça donnerai ça 

```js
const { executeFunction } = require("niod-core");

executeFunction("nomDeLaFonction", {}); // les arguments dans {}, attention il faut que la fonction lua s'attende a recevoir les arguments sous forme de tableau aussi
```

executeFunction renvoie une promesse maintenant (fini les callbacks pas jolis). Tu peux trouver la doc ici: https://ked57.github.io/NIOD-core/modules/_dcs_functions_.html#const-executefunction

Voilà désolé j'imagine que ça casse votre lib, mais vu que je réorganise le truc en deux packages il fallait que je delete l'ancien :frowning:
