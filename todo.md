# This file contains all the ideas for new features and requests for change or correction that we receive

## List

### Idea - needs investigation

- add a Missile Training module that can work with a zone or a radio menu
- add the possibility to spawn a radio beacon (either vanilla or custom, like e.g. the [TACAN from Suntsag](https://www.youtube.com/watch?v=E1xptHG9r7c))
- add a way to request artillery shelling of a zone, and also lighting with flares for a certain time
- add an AWACS module ; see notes about that lower
- find a way to get the data about coordinates in the Scratchpad mod; it works solo, maybe we can make it work multi with the help of SlMod ?
- add a function to help find a town location
- find a way to generate a documentation of all available commands
- change move tanker to me to make it adapt its speed and altitude to the calling aircraft type
- make a module that decorate a ship (statics spawn, SSW escort by subs, helos and S3s, speed and drift DDs)
- create an option that spawns a thing in a radius

### RFC - needs to be done

- modify the "move tanker" command so the tanker new plan is, in the direction from the current tanker position (point 1) to the marker, a point at 20nm of the marker (point 2) and the marker itself (point 3)

### Bug - needs to be corrected

- when the user forgets a comma the convoy is created but without trucks ("-convoy armor 0, defense 0, dest TGT")

## Notes

### add an AWACS module

- like EWRS but better

  - no more chat spamming
  - manage an on-demand picture or bogey dope like the vanilla awacs
  - make the picture clearer and more realistic (see with Couby :
  > Ce qui serait bien dans ce nouveau GCI/AIC automate, c'est qu'il donne une picture dans une zone d'intérêt par rapport au demandeur, et qu'il ajuste la taille de cette zone considérée en fonction de la densité de la picture résultante.
  > Ce qui serait bien aussi c'est de pouvoir paramétrer la notion de threat calls : quand il va donner des informations en BRAA.
  > Et le top, qu'il sache ajuster le contenu en fonction de critères de dangerosité...
  