# Recette PyInstaller du programme autonome `veaf-logs`.
#
# `veaf-tools` est construit par `veaf-build build-standalone` ; `veaf-logs` a
# sa propre recette parce que ses besoins n'ont rien de commun : il embarque Qt
# et rien de la chaine de construction des missions. Les garder separes evite
# aussi de faire grossir `veaf-tools.exe` de plusieurs dizaines de mega-octets
# pour une interface que la plupart de ses utilisateurs n'ouvriront jamais.
#
#   poetry run pyinstaller veaf-logs.spec
#
# Produit `dist/veaf-logs.exe` sous Windows, `dist/veaf-logs` ailleurs.

from pathlib import Path

SOURCE = Path("src/python/veaf-tools")

# Modules Qt dont l'application n'a aucun usage. Sans ces exclusions, PyInstaller
# embarque le moteur web, la 3D et le multimedia — plusieurs centaines de
# mega-octets pour rien.
UNUSED_QT = [
    "PySide6.Qt3DAnimation",
    "PySide6.Qt3DCore",
    "PySide6.Qt3DExtras",
    "PySide6.Qt3DInput",
    "PySide6.Qt3DLogic",
    "PySide6.Qt3DRender",
    "PySide6.QtCharts",
    "PySide6.QtDataVisualization",
    "PySide6.QtMultimedia",
    "PySide6.QtMultimediaWidgets",
    "PySide6.QtOpenGL",
    "PySide6.QtOpenGLWidgets",
    "PySide6.QtPdf",
    "PySide6.QtPdfWidgets",
    "PySide6.QtQml",
    "PySide6.QtQuick",
    "PySide6.QtQuick3D",
    "PySide6.QtQuickWidgets",
    "PySide6.QtSql",
    "PySide6.QtTest",
    "PySide6.QtWebEngineCore",
    "PySide6.QtWebEngineWidgets",
]

analysis = Analysis(
    [str(SOURCE / "veaf_logs" / "__main__.py")],
    pathex=[str(SOURCE)],
    binaries=[],
    # Le catalogue de regles est lu au demarrage, a cote du module.
    datas=[(str(SOURCE / "veaf_logs" / "rules.json"), "veaf_logs")],
    hiddenimports=[],
    hookspath=[],
    runtime_hooks=[],
    excludes=UNUSED_QT + ["tkinter", "unittest", "pytest"],
    noarchive=False,
)

pyz = PYZ(analysis.pure)

exe = EXE(
    pyz,
    analysis.scripts,
    analysis.binaries,
    analysis.datas,
    [],
    name="veaf-logs",
    debug=False,
    strip=False,
    upx=False,
    # Pas de console : c'est une application a fenetre.
    console=False,
    disable_windowed_traceback=False,
)
