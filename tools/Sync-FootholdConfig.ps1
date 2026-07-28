<#
.SYNOPSIS
    Reproduce the common part of one Foothold `mission.yaml` across the other missions.

.DESCRIPTION
    The ten VEAF Foothold missions want the same configuration — same VEAF modules, same
    `config_override` values, same build variants — but each `mission.yaml` also carries parts
    that are irreducibly its own, and `mission.yaml` has no include/inherit mechanism.

    So: tune ONE mission by hand, then run this to copy the shared blocks onto the others.

    | Copied from the reference        | Left untouched in each target                |
    |----------------------------------|----------------------------------------------|
    | `global_log_level`               | `conversion_profile`                         |
    | `modules:`                       | `custom_scripts:` (setup script differs per map) |
    | `pipeline:`                      | `strip_native_triggers:` (trigger names differ) |
    | `config_override:` → `values:`   | `config_override:` → `target:` (WW2 differs) |
    | `build_variants:`, `profiles:`   | `mission:` (its name)                        |

    Blocks are moved as whole text spans, comments included — nothing is re-serialised, so a
    target keeps its own formatting and the reference's comments travel with what they document.

    **Nothing is written unless you pass -Apply.** The default run reports what would change.

.PARAMETER Reference
    The mission folder (or the `mission.yaml` itself) to copy from — the one you tuned by hand.

.PARAMETER MissionsFolder
    Folder holding the mission subfolders. Every one except the reference is a target.

.PARAMETER Apply
    Actually write. Without it the script only reports, which is the safe default when nine
    files are at stake.

.PARAMETER Keys
    Top-level blocks to copy. Defaults to the agreed set; override to copy more or fewer.
    `config_override` is special-cased: only its `values:` sub-block travels, so each mission
    keeps its own `target:`.

.PARAMETER IncludeOtherProfiles
    By default a mission whose `conversion_profile` differs from the reference's is **skipped**:
    WWII Normandy (`foothold-ww2`) has no `Era` global, so the reference's era variants and
    `Era`/`StartNormal` overrides do not apply to it and would produce a config `validate`
    rejects. Configure it by hand. Pass this to sync it anyway.

.EXAMPLE
    # See what would change.
    .\Sync-FootholdConfig.ps1 -Reference D:\veaf\foothold-v6\Foothold_CA_4.4.1_... `
        -MissionsFolder D:\veaf\foothold-v6

.EXAMPLE
    # Do it, keeping a .bak of every file touched.
    .\Sync-FootholdConfig.ps1 -Reference D:\veaf\foothold-v6\Foothold_CA_4.4.1_... `
        -MissionsFolder D:\veaf\foothold-v6 -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Reference,
    [Parameter(Mandatory)] [string] $MissionsFolder,
    [switch] $Apply,
    [string[]] $Keys = @('global_log_level', 'modules', 'pipeline', 'config_override', 'build_variants', 'profiles'),
    [switch] $IncludeOtherProfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-MissionYaml {
    <#  Accept either a mission folder or a mission.yaml path.  #>
    param([string] $PathOrFolder)

    if (-not (Test-Path -LiteralPath $PathOrFolder)) { throw "Introuvable : $PathOrFolder" }
    $resolved = (Resolve-Path -LiteralPath $PathOrFolder).Path
    if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
        $candidate = Join-Path $resolved 'mission.yaml'
        if (-not (Test-Path -LiteralPath $candidate)) { throw "Pas de mission.yaml dans $resolved" }
        return $candidate
    }
    return $resolved
}

function Get-TopLevelBlock {
    <#  Return the text span of a top-level YAML block, comments above it included.

        A top-level block runs from its `key:` line to the next line starting in column 0 that
        is neither blank nor a comment. Leading comment lines directly above the key are taken
        along, because in this file they document the block (and would otherwise be orphaned).

        Returns $null when the key is absent. Returns @{Start;End;Text} with End exclusive.  #>
    param([string[]] $Lines, [string] $Key)

    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -cmatch "^$([regex]::Escape($Key)):") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }

    # Walk back over the comment block immediately above.
    $withComments = $start
    while ($withComments -gt 0 -and $Lines[$withComments - 1] -match '^\s*#') { $withComments-- }

    $end = $Lines.Count
    for ($i = $start + 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line -match '^\S' -and $line -notmatch '^\s*#') { $end = $i; break }
    }
    # Give back the comment block sitting directly above the NEXT key: it documents that key,
    # not this one. Without this, propagating a block duplicates the next block's header.
    while ($end -gt $start + 1 -and $Lines[$end - 1] -match '^\s*#') { $end-- }
    # Trim trailing blank lines so re-inserting does not accumulate them.
    while ($end -gt $start + 1 -and [string]::IsNullOrWhiteSpace($Lines[$end - 1])) { $end-- }

    return @{ Start = $withComments; End = $end; Text = $Lines[$withComments..($end - 1)] }
}

function Get-NestedBlock {
    <#  Return the span of a second-level block (e.g. `values:` inside `config_override:`).
        Indented lines belong to it until a line at the parent's indentation or less.  #>
    param([string[]] $Lines, [int] $ParentStart, [int] $ParentEnd, [string] $Key)

    for ($i = $ParentStart; $i -lt $ParentEnd; $i++) {
        if ($Lines[$i] -cmatch "^(\s+)$([regex]::Escape($Key)):") {
            $indent = $Matches[1].Length
            $end = $ParentEnd
            for ($j = $i + 1; $j -lt $ParentEnd; $j++) {
                $line = $Lines[$j]
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $currentIndent = ($line -replace '^(\s*).*', '$1').Length
                if ($currentIndent -le $indent) { $end = $j; break }
            }
            while ($end -gt $i + 1 -and [string]::IsNullOrWhiteSpace($Lines[$end - 1])) { $end-- }
            return @{ Start = $i; End = $end; Text = $Lines[$i..($end - 1)] }
        }
    }
    return $null
}

function Get-CommentedOverrideTarget {
    <#  Read the `target:` from a COMMENTED config_override scaffold.

        `convert-other` emits the block commented out, with the target its conversion profile
        prescribes — `Foothold Config.lua`, or `Foothold Config WW2.lua` for Normandy. That is
        exactly the per-mission value we must keep, so harvest it from the target file instead of
        asking the operator to uncomment nine files by hand.  #>
    param([string[]] $Lines)

    $inBlock = $false
    foreach ($line in $Lines) {
        if ($line -cmatch '^#\s*config_override:') { $inBlock = $true; continue }
        if ($inBlock) {
            if ($line -notmatch '^\s*#') { break }
            if ($line -cmatch '^#\s+target:\s*(.+?)\s*$') { return $Matches[1] }
        }
    }
    return $null
}

function Get-ScalarValue {
    <#  Read a top-level scalar (`conversion_profile: foothold`). $null when absent.  #>
    param([string[]] $Lines, [string] $Key)

    foreach ($line in $Lines) {
        if ($line -cmatch "^$([regex]::Escape($Key)):\s*(.+?)\s*$") { return $Matches[1] }
    }
    return $null
}

function Set-Block {
    <#  Replace a top-level block in $Lines with $NewText, or append it when absent.
        Returns the new line array.  #>
    param([string[]] $Lines, [string] $Key, [string[]] $NewText)

    $existing = Get-TopLevelBlock -Lines $Lines -Key $Key
    if ($existing) {
        $before = if ($existing.Start -gt 0) { $Lines[0..($existing.Start - 1)] } else { @() }
        $after = if ($existing.End -lt $Lines.Count) { $Lines[$existing.End..($Lines.Count - 1)] } else { @() }
        return @($before) + @($NewText) + @($after)
    }
    return @($Lines) + @('') + @($NewText)
}

# ── Preflight ────────────────────────────────────────────────────────────────────────────
$refYaml = Resolve-MissionYaml -PathOrFolder $Reference
$refLines = Get-Content -LiteralPath $refYaml
$refFolder = Split-Path -Parent $refYaml
$refProfile = Get-ScalarValue -Lines $refLines -Key 'conversion_profile'

if (-not (Test-Path -LiteralPath $MissionsFolder)) { throw "Dossier introuvable : $MissionsFolder" }
$MissionsFolder = (Resolve-Path -LiteralPath $MissionsFolder).Path

# Collect the reference blocks once.
$refBlocks = @{}
foreach ($key in $Keys) {
    if ($key -eq 'config_override') { continue }   # handled through its values: sub-block
    $block = Get-TopLevelBlock -Lines $refLines -Key $key
    if ($block) { $refBlocks[$key] = $block.Text }
}

$refValues = $null
if ($Keys -contains 'config_override') {
    $co = Get-TopLevelBlock -Lines $refLines -Key 'config_override'
    if ($co) {
        $refValues = Get-NestedBlock -Lines $refLines -ParentStart $co.Start -ParentEnd $co.End -Key 'values'
    }
}

Write-Host ''
Write-Host "Référence      : $refYaml"
Write-Host "Profil réf.    : $($refProfile ?? '(aucun)')"
Write-Host "Blocs copiés   : $(($refBlocks.Keys | Sort-Object) -join ', ')$(if ($refValues) { ', config_override.values' })"
Write-Host "Missions       : $MissionsFolder"
Write-Host "Mode           : $(if ($Apply) { 'ÉCRITURE (sauvegarde .bak par fichier)' } else { 'simulation — rien ne sera écrit' })"
Write-Host ''

$missing = @($Keys | Where-Object { $_ -ne 'config_override' -and -not $refBlocks.ContainsKey($_) })
if ($missing.Count -gt 0) {
    Write-Warning "Absents de la référence, donc non propagés : $($missing -join ', ')"
    Write-Host ''
}

# ── Sync ─────────────────────────────────────────────────────────────────────────────────
$touched = 0; $skipped = 0

foreach ($folder in (Get-ChildItem -LiteralPath $MissionsFolder -Directory | Sort-Object Name)) {
    $yaml = Join-Path $folder.FullName 'mission.yaml'
    if (-not (Test-Path -LiteralPath $yaml)) { continue }
    if ((Resolve-Path -LiteralPath $folder.FullName).Path -eq (Resolve-Path -LiteralPath $refFolder).Path) { continue }

    $lines = Get-Content -LiteralPath $yaml
    $targetProfile = Get-ScalarValue -Lines $lines -Key 'conversion_profile'

    Write-Host $folder.Name -ForegroundColor Cyan

    if ($targetProfile -ne $refProfile -and -not $IncludeOtherProfiles) {
        Write-Host "    ignoré — profil '$($targetProfile ?? "aucun")' ≠ référence '$($refProfile ?? "aucun")'" -ForegroundColor Yellow
        Write-Host '      (à configurer à la main ; -IncludeOtherProfiles pour forcer)'
        $skipped++
        Write-Host ''
        continue
    }

    $updated = $lines
    $changes = @()

    foreach ($key in ($refBlocks.Keys | Sort-Object)) {
        $before = Get-TopLevelBlock -Lines $updated -Key $key
        $verb = if ($before) { if (($before.Text -join "`n") -eq ($refBlocks[$key] -join "`n")) { 'identique' } else { 'remplacé' } } else { 'ajouté' }
        if ($verb -ne 'identique') {
            $updated = Set-Block -Lines $updated -Key $key -NewText $refBlocks[$key]
            $changes += "$key ($verb)"
        }
    }

    if ($refValues) {
        $co = Get-TopLevelBlock -Lines $updated -Key 'config_override'
        if (-not $co) {
            # No active block: build one from the target this mission's own commented scaffold
            # names (per conversion profile), plus the reference's values.
            $ownTarget = Get-CommentedOverrideTarget -Lines $updated
            if (-not $ownTarget) {
                Write-Host '    config_override introuvable, même commenté — ajoutez-le à la main puis relancez' -ForegroundColor Yellow
            }
            else {
                $block = @(
                    '# Partial override of the untouched upstream config (ADR 0008). Values synced from',
                    "# the reference mission; target is this mission's own.",
                    'config_override:',
                    "  target: $ownTarget"
                ) + $refValues.Text
                $updated = Set-Block -Lines $updated -Key 'config_override' -NewText $block
                $changes += "config_override (créé, target $ownTarget)"
            }
        }
        else {
            $existingValues = Get-NestedBlock -Lines $updated -ParentStart $co.Start -ParentEnd $co.End -Key 'values'
            if ($existingValues) {
                if (($existingValues.Text -join "`n") -ne ($refValues.Text -join "`n")) {
                    $before = if ($existingValues.Start -gt 0) { $updated[0..($existingValues.Start - 1)] } else { @() }
                    $after = if ($existingValues.End -lt $updated.Count) { $updated[$existingValues.End..($updated.Count - 1)] } else { @() }
                    $updated = @($before) + @($refValues.Text) + @($after)
                    $changes += 'config_override.values (remplacé)'
                }
            }
            else {
                # Append values: at the end of the config_override block.
                $before = $updated[0..($co.End - 1)]
                $after = if ($co.End -lt $updated.Count) { $updated[$co.End..($updated.Count - 1)] } else { @() }
                $updated = @($before) + @($refValues.Text) + @($after)
                $changes += 'config_override.values (ajouté)'
            }
        }
    }

    if ($changes.Count -eq 0) {
        Write-Host '    déjà à jour' -ForegroundColor DarkGray
    }
    else {
        Write-Host "    $($changes -join ' · ')"
        # Report what is deliberately preserved, so the operator sees it is untouched.
        foreach ($kept in @('conversion_profile', 'custom_scripts', 'strip_native_triggers')) {
            if (Get-TopLevelBlock -Lines $updated -Key $kept) { continue }
        }
        if ($Apply) {
            $backup = "$yaml.bak"
            if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $yaml -Destination $backup }
            Set-Content -LiteralPath $yaml -Value $updated -Encoding UTF8
            Write-Host '    écrit' -ForegroundColor Green
        }
        $touched++
    }
    Write-Host ''
}

# ── Summary ──────────────────────────────────────────────────────────────────────────────
Write-Host "$touched mission(s) $(if ($Apply) { 'mise(s) à jour' } else { 'à mettre à jour' })$(if ($skipped) { ", $skipped ignorée(s)" })" -ForegroundColor Green
if (-not $Apply -and $touched -gt 0) {
    Write-Host 'Relancez avec -Apply pour écrire (une sauvegarde .bak sera faite par fichier).'
}
if ($Apply -and $touched -gt 0) {
    Write-Host "Pensez à revalider : Convert-FootholdBatch.ps1 … -Validate (ou 'veaf-tools validate <dossier>')."
}
exit 0
