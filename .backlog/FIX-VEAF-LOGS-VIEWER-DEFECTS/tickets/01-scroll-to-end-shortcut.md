# 01 — *Aller à la fin* gets its shortcut

Status: ✅ done

`ui/main_window.py` declares `"Ctrl+Fin"`, which Qt does not parse (`QKeySequence("Ctrl+Fin")` is empty), so the action has no shortcut. Use `Ctrl+End`; a test asserts the action's shortcut is not empty.
