<#
.SYNOPSIS
    Adopt every Lekaa Foothold release archive of a folder onto the VEAF v6 toolchain.

.DESCRIPTION
    Runs `veaf-tools convert-other` once per `.zip` found in -InputFolder, each into a subfolder
    of -OutputFolder. Lekaa ships one archive per map (Caucasus, Persian Gulf, Sinai, Syria, Cold
    War Germany, Kola, Iraq, Afghanistan, WWII Normandy), so a release means ten adoptions — this
    does them in one pass.

    The target folder is matched by **theatre**, read from the mission table inside the archive
    and from each adopted folder's `src/mission/mission`. So a release archive refreshes
    `VEAF-Foothold-Caucasus` even though it is named `Foothold_CA_4.7.0_Multi_Language…`. A
    folder already named after the archive still wins, and an ambiguous theatre (two adopted
    folders on the same map) is reported rather than guessed. Anything unmatched is a fresh
    adoption into a folder named after the archive, as before.

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
    Where the mission folders live. An archive is matched to the existing folder of the same
    theatre; anything unmatched gets a new subfolder named after the archive. Created if missing.

.PARAMETER VeafTools
    Path to `veaf-tools.exe`. When omitted, the script looks beside the -SharedPublished bundle
    (publish-local leaves the executable next to `published/`, not inside it), then in
    -OutputFolder, then in `<OutputFolder>\_toolchain`, then in -InputFolder, then on the PATH.

.PARAMETER Update
    Re-import into mission folders that already exist (`convert-other --update`): refreshes the
    third-party scripts, preserves each tuned `mission.yaml`, and reports what changed
    upstream. Without it, an existing `mission.yaml` is left untouched. This is the mode for
    every Foothold release after the first.

.PARAMETER Validate
    Run `veaf-tools validate` on each mission folder after adopting it, so a batch of ten
    tells you which ones are sane.

.PARAMETER Build
    Build each mission after adopting it. Implies -Validate: building a mission that does not
    validate wastes minutes per folder.

    Two things are checked before building, and reported per mission rather than silently
    accepted: a `mission.yaml` whose `config_override` is still commented out (the mission would
    ship without its Era / FootholdLocale), and a `pipeline.weather` step still enabled (which
    multiplies every mission by its weather variants).

    After building, the `.miz` files present are compared with the name `mission.yaml` asks for.
    A file left over from an earlier build under a different name is flagged: on the VEAF servers
    the name is an interface — RealWeather reads `_ICAO_<code>` from it — so deploying a stale one
    silently pulls the weather of the wrong airfield.

    A previous build under the **same** name is flagged too. The output is
    `<name>_<YYYYMMDD>[_<VARIANT>].miz`, so yesterday's build sits beside today's and both match
    the expected name — which is how five missions kept a 20260728 build next to their 20260825
    one, unnoticed. Only the latest date per name and variant is the current build; two variants
    of the same day are not duplicates, and a `.miz` carrying no date is left alone.

.PARAMETER SharedPublished
    Path to a **shared** `published/` folder (the one `veaf-build publish-local` or the updater
    produces), passed to the build as `--scripts-path`. Without it every mission folder needs
    its own copy — around 58 MB each.

    Note the path must be the `published` folder itself, not its parent.

    The build persists `--scripts-path` into `mission.yaml` (`build.scripts_path`) and the path
    is machine-specific, so this script **removes that key again** after each build. Your
    `mission.yaml` is left as you wrote it.

.EXAMPLE
    # First adoption of a release.
    .\Convert-FootholdBatch.ps1 -InputFolder D:\downloads\foothold-4.4.1 -OutputFolder D:\veaf\foothold-v6

.EXAMPLE
    # Next release: refresh the same folders, keeping every tuned mission.yaml, and check them all.
    .\Convert-FootholdBatch.ps1 -InputFolder D:\downloads\foothold-4.5.0 `
        -OutputFolder D:\veaf\foothold-v6 -Update -Validate

.EXAMPLE
    # Refresh and rebuild the ten missions against one shared scripts bundle.
    .\Convert-FootholdBatch.ps1 -InputFolder D:\downloads\foothold-4.5.0 `
        -OutputFolder D:\veaf\foothold-v6 -Update -Build `
        -SharedPublished D:\veaf\foothold-v6\_published

.NOTES
    Expect roughly a minute per mission for the adoption alone; -Build adds a few more each.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputFolder,
    [Parameter(Mandatory)] [string] $OutputFolder,
    [string] $VeafTools,
    [switch] $Update,
    [switch] $Validate,
    [switch] $Build,
    [string] $SharedPublished
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Matching a release archive to the mission folder it belongs to, and spotting a previous build
# left beside the new one. Their own files so tests can dot-source them without this script's
# mandatory parameters starting a conversion.
. (Join-Path $PSScriptRoot 'Resolve-MissionFolder.ps1')
. (Join-Path $PSScriptRoot 'Get-SupersededMiz.ps1')

# Marker file that identifies a WWII Foothold: it carries its own config, with no Era global.
$Ww2ConfigName = 'Foothold Config WW2.lua'

# Windows caps full paths; Foothold's archive names are long, so warn before a build trips on it.
$LongPathWarnThreshold = 180

function Resolve-VeafTools {
    <#  Locate veaf-tools.exe, in order: the explicit parameter; next to a -SharedPublished
        bundle (publish-local drops the executable beside published/, not inside it); the output
        folder; the output folder's _toolchain/; the input folder; the PATH.  #>
    param([string] $Explicit, [string] $OutputFolder, [string] $InputFolder, [string] $SharedPublished)

    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "veaf-tools introuvable : $Explicit" }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }

    $folders = [System.Collections.Generic.List[string]]::new()
    if ($SharedPublished) { $folders.Add((Split-Path -Parent $SharedPublished)) }
    $folders.Add($OutputFolder)
    $folders.Add((Join-Path $OutputFolder '_toolchain'))
    $folders.Add($InputFolder)

    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        $candidate = Join-Path $folder 'veaf-tools.exe'
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    $onPath = Get-Command 'veaf-tools.exe' -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    # Single-quoted here-string: a double-quoted one would read the backtick before
    # `veaf-build` as an escape and print "eaf-build".
    throw @'
veaf-tools.exe introuvable. Passez -VeafTools <chemin>, ou déposez l'exécutable à côté du
dossier published partagé, dans le dossier de sortie (ou son sous-dossier _toolchain), ou
dans le dossier d'entrée — c'est là que l'updater et "veaf-build publish-local" le laissent.
'@
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

function Read-Utf8Lines {
    <#  Read a UTF-8 file as lines, whatever the PowerShell edition.

        `Get-Content` without -Encoding reads ANSI on Windows PowerShell 5.1, so a UTF-8
        mission.yaml comes back with its accents and box-drawing characters mangled — and
        writing it out again corrupts the file (it produced U+009D in eight mission.yaml
        comments before this was fixed). The .NET API is unambiguous on both editions.  #>
    param([string] $Path)
    return [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Lines {
    <#  Write lines back as UTF-8 without BOM, preserving what Read-Utf8Lines read.  #>
    param([string] $Path, [string[]] $Lines)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Get-PreBuildWarnings {
    <#  Return the reasons this mission is probably not ready to build.

        Both are worth catching before spending minutes on a build: an untouched
        `config_override` ships a mission without its Era / FootholdLocale, and the weather step
        turns one mission into one .miz per declared version. Text inspection on purpose — there
        is no YAML parser in PowerShell and both markers are unambiguous.

        Case matters here: `-cmatch`, not `-match`. The scaffold carries a `WEATHER: true` VEAF
        *module*, which an insensitive match confuses with the `weather:` pipeline step.  #>
    param([string] $MissionYaml, [string] $MissionFolder)

    $warnings = @()
    if (-not (Test-Path -LiteralPath $MissionYaml)) { return @('mission.yaml absent') }
    $lines = Read-Utf8Lines -Path $MissionYaml

    if (-not ($lines | Where-Object { $_ -cmatch '^config_override:' })) {
        if ($lines | Where-Object { $_ -cmatch '^#\s*config_override:' }) {
            $warnings += 'config_override encore commenté (ni Era ni FootholdLocale ne seront appliqués)'
        }
    }

    # The weather step reads src/versions.yaml and emits one .miz per version declared there.
    # It only bites when that file exists, so do not cry wolf on a folder without it.
    $versions = Join-Path $MissionFolder 'src/versions.yaml'
    if (Test-Path -LiteralPath $versions) {
        $weatherOff = $lines | Where-Object { $_ -cmatch '^\s+weather:\s*false' }
        if (-not $weatherOff) {
            $warnings += "src/versions.yaml présent et l'étape weather n'est pas désactivée — un .miz par version déclarée. Ajoutez 'pipeline:' / '  weather: false' au mission.yaml."
        }
    }
    return $warnings
}

function Test-MizNaming {
    <#  Compare the .miz files present with the name mission.yaml asks for.

        The build names its output after `mission.name`, and on the VEAF servers that name is an
        interface: RealWeather reads `_ICAO_<code>` from it. A .miz left over from an earlier
        build under a different name is therefore not just clutter — deploy it and the mission
        pulls the weather of the wrong airfield, silently. That happened for real on five
        missions when their ICAO codes were corrected.

        Returns @{Expected; Matching; Stale}: the expected base name, the files that match it
        (several is normal — weather or era variants suffix it), and those that do not.  #>
    param([string] $MissionFolder, [string] $MissionYaml)

    $expected = $null
    if (Test-Path -LiteralPath $MissionYaml) {
        foreach ($line in (Read-Utf8Lines -Path $MissionYaml)) {
            # `name:` indented under `mission:`; stop at the first, ignore any trailing comment.
            if ($line -cmatch '^\s+name:\s*([^\s#]+)') { $expected = $Matches[1]; break }
        }
    }

    $all = @(Get-ChildItem -LiteralPath $MissionFolder -Filter '*.miz' -File -ErrorAction SilentlyContinue) +
           @(Get-ChildItem -LiteralPath (Join-Path $MissionFolder 'missions') -Filter '*.miz' -File -ErrorAction SilentlyContinue)

    if (-not $expected) {
        # No mission.name: the build falls back to its own default, so nothing to compare against.
        return @{ Expected = $null; Matching = @($all | ForEach-Object Name); Stale = @() }
    }
    $matching = @($all | Where-Object { $_.Name -like "$expected`_*" } | ForEach-Object Name)
    $stale = @($all | Where-Object { $_.Name -notlike "$expected`_*" } | ForEach-Object Name)
    return @{ Expected = $expected; Matching = $matching; Stale = $stale }
}

function Remove-PersistedScriptsPath {
    <#  Drop the `build.scripts_path` key the build persists when --scripts-path is used.

        The path is machine-specific (the generated comment says so), so leaving it in a
        mission.yaml that may be shared or committed would be wrong.  #>
    param([string] $MissionYaml)

    if (-not (Test-Path -LiteralPath $MissionYaml)) { return }
    $content = Read-Utf8Lines -Path $MissionYaml
    $kept = $content | Where-Object { $_ -notmatch '^\s+scripts_path:\s*' }
    if ($kept.Count -ne $content.Count) {
        Write-Utf8Lines -Path $MissionYaml -Lines $kept
    }
}

function Invoke-VeafTools {
    <#  Run veaf-tools and return $true on success. Its full output is printed on failure only,
        so a ten-mission batch stays readable — but warnings are surfaced even on success:
        hiding them once cost us every mission being named mission_<date>.miz while veaf-tools
        was saying so on every run.

        `WorkingDirectory` matters for the build, which resolves `published/` relative to the
        current directory.  #>
    param([string] $Exe, [string[]] $Arguments, [string] $WorkingDirectory)

    $previous = $null
    if ($WorkingDirectory) {
        $previous = (Get-Location).Path
        Set-Location -LiteralPath $WorkingDirectory
    }
    try {
        $output = & $Exe @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host '    --- sortie de veaf-tools ---' -ForegroundColor DarkGray
            $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            return $false
        }
        $flagged = @($output | Where-Object { $_ -match 'invalide|introuvable|manquant|ignoré|avertissement|WARNING' })
        foreach ($line in $flagged) { Write-Host "    ! $line" -ForegroundColor Yellow }
        return $true
    }
    finally {
        if ($previous) { Set-Location -LiteralPath $previous }
    }
}

# ── Preflight ────────────────────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $InputFolder)) { throw "Dossier d'entrée introuvable : $InputFolder" }
$InputFolder = (Resolve-Path -LiteralPath $InputFolder).Path

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
$OutputFolder = (Resolve-Path -LiteralPath $OutputFolder).Path

# Building a mission that does not validate wastes minutes per folder.
if ($Build) { $Validate = $true }

# Resolve -SharedPublished BEFORE looking for the executable: the bundle's parent folder is
# where publish-local leaves veaf-tools.exe, so it is the best place to find it.
if ($SharedPublished) {
    if (-not (Test-Path -LiteralPath $SharedPublished)) {
        throw "Dossier published partagé introuvable : $SharedPublished"
    }
    $SharedPublished = (Resolve-Path -LiteralPath $SharedPublished).Path
    # A published/ bundle carries the community scripts under src/scripts/community/.
    if (-not (Test-Path -LiteralPath (Join-Path $SharedPublished 'src/scripts/community/mist.lua'))) {
        throw @"
$SharedPublished ne ressemble pas à un dossier published (src/scripts/community/mist.lua absent).
-SharedPublished attend le dossier 'published' lui-même, pas son parent.
"@
    }
}

$exe = Resolve-VeafTools -Explicit $VeafTools -OutputFolder $OutputFolder `
    -InputFolder $InputFolder -SharedPublished $SharedPublished

$archives = @(Get-ChildItem -LiteralPath $InputFolder -Filter '*.zip' -File | Sort-Object Name)
if ($archives.Count -eq 0) { throw "Aucune archive .zip dans $InputFolder" }

$steps = @('adoption')
if ($Validate) { $steps += 'validation' }
if ($Build) { $steps += 'build' }

Write-Host ''
Write-Host "veaf-tools   : $exe"
Write-Host "Entrée       : $InputFolder"
Write-Host "Sortie       : $OutputFolder"
Write-Host "Missions     : $($archives.Count) archive(s)$(if ($Update) { ' — mode mise à jour' })"
Write-Host "Étapes       : $($steps -join ' → ')"
if ($SharedPublished) { Write-Host "Scripts VEAF : $SharedPublished (partagé)" }
Write-Host ''

# ── Batch ────────────────────────────────────────────────────────────────────────────────
$results = [System.Collections.Generic.List[object]]::new()
$index = 0

foreach ($archive in $archives) {
    $index++
    $name = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)

    # The archive name carries the version and the mission folders are named after the map, so
    # the target is resolved by theatre rather than assumed from the file name.
    $resolved = Resolve-MissionFolder -OutputFolder $OutputFolder -ArchivePath $archive.FullName
    $target = $resolved.Path

    Write-Host "[$index/$($archives.Count)] $name" -ForegroundColor Cyan
    if ($resolved.Matched) {
        Write-Host "    dossier : $(Split-Path -Leaf $target) ($($resolved.Reason))"
    } else {
        Write-Host "    dossier : $(Split-Path -Leaf $target) — nouveau ($($resolved.Reason))"
    }

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
    $built = $null

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
        if ($Build -and $validated) {
            $missionYaml = Join-Path $target 'mission.yaml'
            foreach ($w in (Get-PreBuildWarnings -MissionYaml $missionYaml -MissionFolder $target)) {
                Write-Warning "    $w"
            }
            # No positional argument: `build`'s FIRST positional is the mission NAME, not the
            # folder. Passing '.' made it the name, which is invalid, so it fell back to
            # "mission" and the mission.yaml's `mission.name` was never read — every mission
            # came out as mission_<date>.miz. The folder defaults to '.', and we already run
            # from it.
            $buildArgs = @('build')
            if ($SharedPublished) { $buildArgs += @('--scripts-path', $SharedPublished) }
            # The build resolves published/ from the current directory, hence -WorkingDirectory.
            $built = Invoke-VeafTools -Exe $exe -Arguments $buildArgs -WorkingDirectory $target
            if ($SharedPublished) { Remove-PersistedScriptsPath -MissionYaml $missionYaml }
            if ($built) {
                $naming = Test-MizNaming -MissionFolder $target -MissionYaml $missionYaml
                Write-Host "    construit — $($naming.Matching.Count) .miz" -ForegroundColor Green
                if ($naming.Expected -and $naming.Matching.Count -eq 0) {
                    Write-Warning "    aucun .miz nommé d'après mission.name ($($naming.Expected)) — vérifiez le build"
                }
                foreach ($stale in $naming.Stale) {
                    Write-Warning "    .miz périmé, d'un build antérieur sous un autre nom : $stale"
                }
                # The other way to end up deploying the wrong file: the previous build under the
                # *same* name, only the date differing. Both match mission.name, so the check
                # above says nothing about it.
                $superseded = @(Get-SupersededMiz -Names $naming.Matching)
                foreach ($old in $superseded) {
                    Write-Warning "    .miz d'un build antérieur, même nom : $old"
                }
                if ($naming.Stale.Count -gt 0 -or $superseded.Count -gt 0) {
                    Write-Host '      supprimez-les pour ne pas déployer le mauvais fichier' -ForegroundColor Yellow
                }
            } else {
                Write-Host '    ÉCHEC du build' -ForegroundColor Red
            }
        }
        elseif ($Build) {
            Write-Host '    build ignoré (la validation a échoué)' -ForegroundColor Yellow
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
        Construit = $built
        Dossier   = $target
    })
    Write-Host ''
}

# ── Summary ──────────────────────────────────────────────────────────────────────────────
Write-Host 'Résumé' -ForegroundColor Cyan
$dash = { param($v) if ($null -eq $v) { '-' } else { $v } }
$results | Format-Table -AutoSize -Property Mission, Profil, Converti,
    @{ Name = 'Validé';    Expression = { & $dash $_.Validé } },
    @{ Name = 'Construit'; Expression = { & $dash $_.Construit } }

$failed = @($results | Where-Object { -not $_.Converti -or $_.Validé -eq $false -or $_.Construit -eq $false })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) mission(s) en échec : $($failed.Mission -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "$($results.Count) mission(s) traitée(s) dans $OutputFolder" -ForegroundColor Green
Write-Host ''
if ($Build) {
    Write-Host 'Les .miz sont dans chaque dossier de mission. Il reste à les tester dans DCS.'
} else {
    Write-Host 'Étapes suivantes, par mission : régler le mission.yaml (décommenter config_override,'
    Write-Host "activer les modules VEAF voulus), puis relancer avec -Build."
}
exit 0
