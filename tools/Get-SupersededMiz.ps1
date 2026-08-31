<#
.SYNOPSIS
    Find the .miz files left over from an earlier build of the same mission.

.DESCRIPTION
    `Test-MizNaming` catches a `.miz` whose name does not match what `mission.yaml` asks for. It
    could not catch the other way of ending up with the wrong file: the *previous* build sitting
    beside the new one under the same base name, with only the date differing
    (`…_ICAO_URSS_20260728.miz` next to `…_20260825.miz`). Both matched, so nothing was said —
    and deploying the old one is exactly as silent and as wrong.

    The build names its output `<name>_<YYYYMMDD>[_<VARIANT>].miz`, which makes this decidable
    rather than a guess: group by name **and** variant, and within a group only the latest date
    is the current build. Two variants of the same day are not duplicates — that is what
    `build_variants:` emits on purpose — and a file carrying no date is left alone, since a
    hand-named `.miz` is not ours to judge.

.NOTES
    Part of FIX-CONVERT-OTHER-UPDATE-BLIND-SPOTS, follow-up to the PRD's open product question.
#>

Set-StrictMode -Version Latest

function Get-SupersededMiz {
    <#  Return the names that are earlier builds of a mission also present in its current build.

        Args:
            Names: the `.miz` file names to consider (no paths).

        Returns:
            The names left over from an earlier build, in input order. Empty when every file is
            either current or undatable.  #>
    param([string[]] $Names)

    $dated = @{}
    foreach ($name in $Names) {
        # <base>_<YYYYMMDD>[_<variant>].miz — the variant is part of the identity, the date is not.
        $match = [regex]::Match($name, '^(?<base>.+)_(?<date>\d{8})(?<variant>_.+)?\.miz$')
        if (-not $match.Success) { continue }

        $key = '{0}|{1}' -f $match.Groups['base'].Value, $match.Groups['variant'].Value
        if (-not $dated.ContainsKey($key)) { $dated[$key] = [System.Collections.Generic.List[object]]::new() }
        $dated[$key].Add([PSCustomObject]@{ Name = $name; Date = $match.Groups['date'].Value })
    }

    $superseded = [System.Collections.Generic.List[string]]::new()
    foreach ($group in $dated.Values) {
        if ($group.Count -lt 2) { continue }
        # Sorting the 8-digit stamps as text orders them as dates; the newest one is the build.
        $newest = ($group | Sort-Object -Property Date -Descending | Select-Object -First 1).Date
        foreach ($item in $group) {
            if ($item.Date -ne $newest) { $superseded.Add($item.Name) }
        }
    }

    # Input order, so the batch prints them the way the folder lists them.
    return @($Names | Where-Object { $superseded -contains $_ })
}
