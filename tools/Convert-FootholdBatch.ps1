<#
.SYNOPSIS
    Adopt every Lekaa Foothold release archive of a folder onto the VEAF v6 toolchain.

.DESCRIPTION
    Runs `veaf-tools convert-other` once per `.zip` found in -InputFolder, each into its own
    subfolder of -OutputFolder named after the archive. Lekaa ships one archive per map
    (Caucasus, Persian Gulf, Sinai, Syria, Cold War Germany, Kola, Iraq, Afghanistan, WWII
    Normandy), so a release means ten adoptions — this does them in one pass.

    The conversion profile is picked per mission by looking INSIDE the archive's `.miz`: a
    mission carrying "Foothold Config WW2.lua" is a WWII Foothold and gets `foothold-ww2`,
    everything else gets `foothold`. Detection is by content, not by filename, so a future
    WWII map named differently still resolves correctly (the archive name is only a fallback
    if the archive cannot be read).

    One mission failing never stops the batch: every archive is attempted and a summary is
    printed at the end, with a non-zero exit code if anything failed.

    See doc/mission-maker/FOOTHOLD.md for the full per-mission procedure this automates.

.PARAMETER InputFolder
    Folder holding the release `.zip` archives, as downloaded from
    https://github.com/leka1986/Lekas-Foothold/releases (no need to unzip them).

.PARAMETER OutputFolder
    Where to create one mission subfolder per archive. Created if missing.

.PARAMETER VeafTools
    Path to `veaf-tools.exe`. When omitted, the script looks in -OutputFolder, then in
    -InputFolder, then on the PATH.

.PARAMETER Update
    Re-import into mission folders that already exist (`convert-other --update`): refreshes the
    third-party scripts, preserves each tuned `mission.yaml`, and reports what changed
    upstream. Without it, an existing `mission.yaml` is left untouched. This is the mode for
    every Foothold release after the first.

.PARAMETER Validate
    Run `veaf-tools validate` on each mission folder after adopting it, so a batch of ten
    tells you which ones are sane.

.EXAMPLE
    # First adoption of a release.
    .\Convert-FootholdBatch.ps1 -InputFolder D:\downloads\foothold-4.4.1 -OutputFolder D:\veaf\foothold-v6

.EXAMPLE
    # Next release: refresh the same folders, keeping every tuned mission.yaml, and check them all.
    .\Convert-FootholdBatch.ps1 -InputFolder D:\downloads\foothold-4.5.0 `
        -OutputFolder D:\veaf\foothold-v6 -Update -Validate

.NOTES
    Expect roughly a minute per mission: each Foothold ships ~40 MB of Lua to extract.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputFolder,
    [Parameter(Mandatory)] [string] $OutputFolder,
    [string] $VeafTools,
    [switch] $Update,
    [switch] $Validate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Marker file that identifies a WWII Foothold: it carries its own config, with no Era global.
$Ww2ConfigName = 'Foothold Config WW2.lua'

# Windows caps full paths; Foothold's archive names are long, so warn before a build trips on it.
$LongPathWarnThreshold = 180

function Resolve-VeafTools {
    <#  Locate veaf-tools.exe: explicit parameter, then the output folder (that is where
        `veaf-build publish-local` and the updater drop it), then the input folder, then
        the PATH. #>
    param([string] $Explicit, [string] $OutputFolder, [string] $InputFolder)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "veaf-tools introuvable : $Explicit" }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    foreach ($folder in @($OutputFolder, $InputFolder)) {
        $candidate = Join-Path $folder 'veaf-tools.exe'
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    $onPath = Get-Command 'veaf-tools.exe' -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    throw @"
veaf-tools.exe introuvable. Passez -VeafTools <chemin>, ou déposez l'exécutable dans le dossier
d'entrée ou de sortie (c'est ce que font l'updater et `veaf-build publish-local`).
"@
}

function Get-ConversionProfile {
    <#  Return the profile name for an archive by inspecting the .miz it contains.

        The .lua files live inside the .miz, itself inside the .zip, so this opens a zip
        within a zip. ZipArchive needs a seekable stream, hence the copy into memory (one
        mission at a time, ~10 MB). Any read failure falls back to the archive name.  #>
    param([string] $ArchivePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $outer = $null; $mizStream = $null; $buffer = $null; $inner = $null
    try {
        $outer = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        $mizEntry = $outer.Entries | Where-Object { $_.FullName -like '*.miz' } | Select-Object -First 1
        if (-not $mizEntry) { return 'foothold' }  # convert-other reports the missing .miz itself

        $mizStream = $mizEntry.Open()
        $buffer = New-Object System.IO.MemoryStream
        $mizStream.CopyTo($buffer)
        $buffer.Position = 0
        $inner = New-Object System.IO.Compression.ZipArchive($buffer)

        $isWw2 = $inner.Entries | Where-Object { $_.Name -eq $Ww2ConfigName } | Select-Object -First 1
        if ($isWw2) { return 'foothold-ww2' } else { return 'foothold' }
    }
    catch {
        # Unreadable archive: fall back to the naming convention rather than giving up.
        Write-Warning "Lecture impossible de $([System.IO.Path]::GetFileName($ArchivePath)) ($($_.Exception.Message)) — profil déduit du nom."
        if ([System.IO.Path]::GetFileName($ArchivePath) -match 'WW2|WWII') { return 'foothold-ww2' }
        return 'foothold'
    }
    finally {
        if ($inner) { $inner.Dispose() }
        if ($buffer) { $buffer.Dispose() }
        if ($mizStream) { $mizStream.Dispose() }
        if ($outer) { $outer.Dispose() }
    }
}

function Invoke-VeafTools {
    <#  Run veaf-tools and return $true on success, printing its output only on failure so a
        ten-mission batch stays readable.  #>
    param([string] $Exe, [string[]] $Arguments)

    $output = & $Exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    --- sortie de veaf-tools ---' -ForegroundColor DarkGray
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        return $false
    }
    return $true
}

# ── Preflight ────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $InputFolder)) { throw "Dossier d'entrée introuvable : $InputFolder" }
$InputFolder = (Resolve-Path -LiteralPath $InputFolder).Path

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
$OutputFolder = (Resolve-Path -LiteralPath $OutputFolder).Path

$exe = Resolve-VeafTools -Explicit $VeafTools -OutputFolder $OutputFolder -InputFolder $InputFolder

$archives = @(Get-ChildItem -LiteralPath $InputFolder -Filter '*.zip' -File | Sort-Object Name)
if ($archives.Count -eq 0) { throw "Aucune archive .zip dans $InputFolder" }

Write-Host ''
Write-Host "veaf-tools   : $exe"
Write-Host "Entrée       : $InputFolder"
Write-Host "Sortie       : $OutputFolder"
Write-Host "Missions     : $($archives.Count) archive(s)$(if ($Update) { ' — mode mise à jour' })"
Write-Host ''

# ── Batch ────────────────────────────────────────────────────────────────────────────────
$results = [System.Collections.Generic.List[object]]::new()
$index = 0

foreach ($archive in $archives) {
    $index++
    $name = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
    $target = Join-Path $OutputFolder $name

    Write-Host "[$index/$($archives.Count)] $name" -ForegroundColor Cyan

    $profileName = Get-ConversionProfile -ArchivePath $archive.FullName
    Write-Host "    profil : $profileName"

    if ($target.Length -gt $LongPathWarnThreshold) {
        Write-Warning "    chemin de sortie long ($($target.Length) caractères) — le build peut buter sur la limite Windows."
    }

    $arguments = @('convert-other', $archive.FullName, $target, '--profile', $profileName)
    $isRefresh = $Update -and (Test-Path -LiteralPath (Join-Path $target 'mission.yaml'))
    if ($isRefresh) { $arguments += '--update' }

    $converted = Invoke-VeafTools -Exe $exe -Arguments $arguments
    $validated = $null

    if ($converted) {
        Write-Host "    adopté$(if ($isRefresh) { ' (mise à jour)' })" -ForegroundColor Green
        if ($Validate) {
            $validated = Invoke-VeafTools -Exe $exe -Arguments @('validate', $target)
            if ($validated) {
                Write-Host '    validé' -ForegroundColor Green
            } else {
                Write-Host '    validation en échec' -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host '    ÉCHEC de la conversion' -ForegroundColor Red
    }

    $results.Add([pscustomobject]@{
        Mission   = $name
        Profil    = $profileName
        Converti  = $converted
        Validé    = $validated
        Dossier   = $target
    })
    Write-Host ''
}

# ── Summary ──────────────────────────────────────────────────────────────────────────────
Write-Host 'Résumé' -ForegroundColor Cyan
$results | Format-Table -AutoSize -Property Mission, Profil, Converti, @{
    Name = 'Validé'; Expression = { if ($null -eq $_.Validé) { '-' } else { $_.Validé } }
}

$failed = @($results | Where-Object { -not $_.Converti -or $_.Validé -eq $false })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) mission(s) en échec : $($failed.Mission -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "$($results.Count) mission(s) adoptée(s) dans $OutputFolder" -ForegroundColor Green
Write-Host ''
Write-Host 'Étapes suivantes, par mission : régler le mission.yaml (décommenter config_override,'
Write-Host "activer les modules VEAF voulus), puis 'veaf-tools build .' depuis son dossier."
exit 0
