# VEAF Mission Creation Tools — 6.11.2

Deux apports depuis la 6.11.0 : **toutes les cartes DCS** ont désormais leurs noms
d'aérodromes, et un correctif important sur les scripts embarqués dans une mission.

## 🌍 Les 14 cartes DCS sont couvertes

**Merci à Reaper**, qui a relevé avec le kit de capture les sept cartes que personne n'avait
encore faites : **Nevada, la Manche, Atlantique Sud (Malouines), Kola, Afghanistan, Irak et
Mariannes 1944**.

La table des aérodromes passe ainsi de 7 à **14 cartes**, et de 657 à **810 terrains**.
Concrètement : un `airport_link` de QRA ou un aérodrome de `warehouses.yaml` se résout
maintenant **sur n'importe quelle carte DCS actuelle**, avec le nom exact reconnu en jeu.

C'est aussi la démonstration que le kit livré en 6.11.0 fonctionne : Reaper a produit les sept
relevés sur sa machine, sans aucun outil de développement.

## 🔧 Un script embarqué dans une mission se charge enfin

Quand un script était embarqué dans une mission par l'assistant IA (ou par le kit de capture),
il **ne se chargeait jamais** : dans l'éditeur DCS, l'action « DO SCRIPT FILE » affichait un
champ FILE **vide**, et rien ne s'exécutait — sans le moindre message d'erreur.

La cause : la référence au fichier était écrite au mauvais endroit dans la mission. Elle est
désormais posée là où DCS la lit réellement. Corrigé aussi : une mission dépourvue de table de
ressources perdait également la référence.

**Signalé par David**, qui a ouvert une mission du kit dans l'éditeur — ce qui a mis en
évidence un défaut touchant *toutes* les missions outillées par l'assistant, pas seulement le
kit.

## 📄 Note

Les missions-pont du **kit de capture de la 6.11.0 étaient affectées** par ce défaut ; son
archive a déjà été remplacée. Si vous l'avez téléchargée avant ce correctif, reprenez-la dans
les fichiers de cette version.
