# 02 — Step 7 stops teaching git, and explains it instead

Status: 🔄 in-progress

Type: docs

## The problem

Step 7 has the reader replace `src/presets.yaml` with a minimal file, then restore it with
`git checkout src/presets.yaml`. Nothing in the walkthrough ever ran `git init` or committed
anything — step 0 merely calls the folder "your Git repository" — so the command cannot work.

Paluche's words: *"je n'ai pas réussi à utiliser la commande « git checkout… » … J'ai relancé alors
la commande « prepare » qui m'a alors demandé si je voulais garder, remplacer certains fichiers.
Ne sachant pas trop que faire, j'ai demandé de tout remplacer. J'ai alors remodifier le
mission.yaml."*

The fallback the page pushed him towards cost him his `mission.yaml` edits. That is ticket 06.

## The decision

Version control is an advanced tool and does not belong in the middle of a first walkthrough. The
step restores by **copy**, which needs nothing installed:

```powershell
Copy-Item src\presets.yaml src\presets.yaml.bak
# … experiment …
Copy-Item src\presets.yaml.bak src\presets.yaml -Force
```

Git keeps a place, but as a **concept worth knowing later**, in a call-out of its own rather than as
a command to type — with a link to Pro Git, which is official, free and translated:

- FR page → <https://git-scm.com/book/fr/v2>
- EN page → <https://git-scm.com/book/en/v2>

Step 0's "ce sera votre dépôt Git" is the other half of the confusion and goes with it: the folder
*can* become one, it is not one.

## Definition of done

- [ ] No `git` command anywhere in the walkthrough
- [ ] Step 7 restores by copy
- [ ] A call-out explains what version control buys a mission maker, and links to Pro Git in the
      page's own language
- [ ] Step 0 no longer asserts the folder is a git repository
- [ ] Both languages
- [ ] `poetry run docs-check` passes
