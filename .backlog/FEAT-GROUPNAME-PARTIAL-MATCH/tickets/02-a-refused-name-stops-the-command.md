# 02 — un nom refusé arrête la commande

Status: ✅ done

Partie de [FEAT-GROUPNAME-PARTIAL-MATCH](../PRD.md).

Le vrai défaut : un `groupname` introuvable retombait sur la recherche de proximité, qui pose le pilote
automatique sur le premier groupe allié à moins de 250 m du marqueur. Le pilote croit commander sa batterie.

Un nom donné qui ne désigne pas **un** groupe doit donc arrêter la commande et le dire — ambiguïté comme
absence. Sans `groupname`, la recherche de proximité ne change pas.

Tests par `executeCommand`, pas par `parseMarkerText` : le refus vit dans `markTextAnalysis`, que les tests du
parseur n'atteignent pas. Et ils posent un groupe sous le marqueur, sinon un refus qui ne s'arrête pas est
indiscernable d'un refus qui s'arrête.

Fini quand retirer le `return nil` du refus fait tomber un test.
