<#
.SYNOPSIS
    Decide which mission folder a Foothold release archive belongs to.

.DESCRIPTION
    Lekaa names each release archive after the release
    (`Foothold_CA_4.7.0_Multi_Language_Coldwar-Modern-Vietnam.zip`); the VEAF mission folders are
    named after the map (`VEAF-Foothold-Caucasus`). Naming the target after the archive — what the
    batch did — meant `-Update` never found an existing `mission.yaml`, silently fell back to a
    fresh adoption, and created one folder per release while refreshing none of the missions. That
    failure is indistinguishable from success until someone reads a `mission.yaml`.

    What identifies a release is the **map**: Lekaa ships one archive per map. So the theatre is
    read from the mission table on both sides — inside the archive's `.miz`, and from each
    candidate folder's exploded `src/mission/mission`.

    Kept in its own file so it can be dot-sourced by a test; `Convert-FootholdBatch.ps1` takes
    mandatory parameters and would start converting.

.NOTES
    Part of FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS, ticket 04.
#>

Set-StrictMode -Version Latest

function Get-MissionTheatre {
    <#  Return the `["theatre"]` a mission table declares, or $null.

        Takes the file's text rather than a path: the caller has it as a stream from inside a
        zip in one case, and as a file in the other.  #>
    param([string] $MissionText)

    if (-not $MissionText) { return $null }
    $match = [regex]::Match($MissionText, '\["theatre"\]\s*=\s*"([^"]+)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-ArchiveTheatre {
    <#  Read the theatre of the `.miz` held in a release `.zip` (or of a bare `.miz`).

        Same zip-inside-a-zip as Get-ConversionProfile: ZipArchive needs a seekable stream, hence
        the copy into memory. Any read failure returns $null, which the caller treats as "cannot
        tell" — never as a match.  #>
    param([string] $ArchivePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $outer = $null; $mizStream = $null; $buffer = $null; $inner = $null; $entryStream = $null
    try {
        if ([System.IO.Path]::GetExtension($ArchivePath) -eq '.miz') {
            $inner = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        }
        else {
            $outer = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
            $mizEntry = $outer.Entries | Where-Object { $_.FullName -like '*.miz' } | Select-Object -First 1
            if (-not $mizEntry) { return $null }

            $mizStream = $mizEntry.Open()
            $buffer = New-Object System.IO.MemoryStream
            $mizStream.CopyTo($buffer)
            $buffer.Position = 0
            $inner = New-Object System.IO.Compression.ZipArchive($buffer)
        }

        $missionEntry = $inner.Entries | Where-Object { $_.FullName -eq 'mission' } | Select-Object -First 1
        if (-not $missionEntry) { return $null }

        $entryStream = $missionEntry.Open()
        $reader = New-Object System.IO.StreamReader($entryStream, [System.Text.Encoding]::UTF8)
        try { return Get-MissionTheatre -MissionText $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    catch {
        Write-Warning "Théâtre illisible dans $([System.IO.Path]::GetFileName($ArchivePath)) ($($_.Exception.Message))."
        return $null
    }
    finally {
        if ($entryStream) { $entryStream.Dispose() }
        if ($inner) { $inner.Dispose() }
        if ($buffer) { $buffer.Dispose() }
        if ($mizStream) { $mizStream.Dispose() }
        if ($outer) { $outer.Dispose() }
    }
}

function Get-MissionFolderTheatre {
    <#  Return the theatre of an adopted mission folder, read from its exploded mission table.

        A folder with no `src/mission/mission` was never fully adopted, so it has nothing to
        match on and returns $null.  #>
    param([string] $MissionFolder)

    $mission = Join-Path $MissionFolder 'src/mission/mission'
    if (-not (Test-Path -LiteralPath $mission)) { return $null }
    try {
        return Get-MissionTheatre -MissionText ([System.IO.File]::ReadAllText($mission, [System.Text.Encoding]::UTF8))
    }
    catch { return $null }
}

function Resolve-MissionFolder {
    <#  Return the folder this archive should be converted into.

        Order: the folder named after the archive when it already holds a `mission.yaml` (so
        anyone using the default naming is unaffected), then the single adopted folder of the
        same theatre. Two candidates of one theatre resolve to neither — refreshing the wrong
        mission is worse than not helping — and say so.

        Returns an object with:
          Path    the folder to convert into
          Matched whether it is an existing mission folder (i.e. `-Update` can engage)
          Reason  what happened, for the batch to print  #>
    param(
        [Parameter(Mandatory)] [string] $OutputFolder,
        [Parameter(Mandatory)] [string] $ArchivePath
    )

    $default = Join-Path $OutputFolder ([System.IO.Path]::GetFileNameWithoutExtension($ArchivePath))

    if (Test-Path -LiteralPath (Join-Path $default 'mission.yaml')) {
        return [PSCustomObject]@{ Path = $default; Matched = $true; Reason = 'dossier portant le nom de l''archive' }
    }

    $theatre = Get-ArchiveTheatre -ArchivePath $ArchivePath
    if (-not $theatre) {
        return [PSCustomObject]@{ Path = $default; Matched = $false; Reason = 'théâtre illisible — adoption' }
    }

    $candidates = @()
    if (Test-Path -LiteralPath $OutputFolder) {
        $candidates = @(
            Get-ChildItem -LiteralPath $OutputFolder -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'mission.yaml') } |
                Where-Object { (Get-MissionFolderTheatre -MissionFolder $_.FullName) -eq $theatre }
        )
    }

    if ($candidates.Count -eq 1) {
        return [PSCustomObject]@{
            Path    = $candidates[0].FullName
            Matched = $true
            Reason  = "théâtre $theatre"
        }
    }
    if ($candidates.Count -gt 1) {
        $names = ($candidates | ForEach-Object { $_.Name }) -join ', '
        return [PSCustomObject]@{
            Path    = $default
            Matched = $false
            Reason  = "théâtre $theatre ambigu ($names) — précisez le dossier à la main"
        }
    }
    return [PSCustomObject]@{ Path = $default; Matched = $false; Reason = "théâtre $theatre inconnu ici — adoption" }
}
