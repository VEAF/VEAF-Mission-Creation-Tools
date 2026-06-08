# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['src\\python\\veaf-tools\\veaf-tools.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('src\\python\\veaf-tools\\veaf_libs\\locales', 'veaf_libs\\locales'),
        ('src\\python\\veaf-tools\\veaf_libs\\veaf_modules_list.json', '.'),
        ('src\\python\\veaf-tools\\presets_injector\\data\\dcs-radio-specs.yaml', 'presets_injector\\data'),
    ],
    hiddenimports=['lupa', 'lupa.lua51'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='veaf-tools',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
