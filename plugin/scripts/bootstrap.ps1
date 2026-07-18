<#
.SYNOPSIS
    Install / refresh the veaf-tools binary the MCP server runs, into the plugin's data dir.

.DESCRIPTION
    Run from the plugin's SessionStart hook (Windows). Drives the SAME veaf-tools-updater the
    tools use inside a mission folder — no new update mechanism:

    - First launch (no veaf-tools.exe yet): download the updater and run it SYNCHRONOUSLY so the
      binary exists before the MCP server needs it. (The MCP may be unavailable on this very first
      session while the install runs; it is ready on the next one.)
    - Subsequent launches: throttled to at most once per 4 h (a timestamp file). When due, run the
      updater DETACHED in the background — it version-checks the release tag and replaces
      veaf-tools.exe (deferred if the current session still holds it locked). The refresh therefore
      takes effect on the next session, which is unavoidable: a running exe cannot replace itself.

    Target release: $env:VEAF_MCP_UPDATER_TAG if set (e.g. published-v6.9.21-rc1 to test a
    pre-release), otherwise "published-latest" (the stable production pointer).

    Failures are non-fatal: the hook exits 0 so a network hiccup never blocks the session.
#>
$ErrorActionPreference = "Stop"

# Never let the updater block on its exit "press a key" pause: a hidden detached window is still
# a real console, so the updater would otherwise wait forever on input() with no one to press a
# key (the plugin bootstrap hang). The updater reads this to force no-pause.
$env:VEAF_UPDATER_NO_PAUSE = "1"

try {
    $dataDir = $env:CLAUDE_PLUGIN_DATA
    if (-not $dataDir) { exit 0 }  # no per-plugin data dir → nothing we can install into
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Force -Path $dataDir | Out-Null }

    $tag = if ($env:VEAF_MCP_UPDATER_TAG) { $env:VEAF_MCP_UPDATER_TAG } else { "published-latest" }
    $repo = "VEAF/VEAF-Mission-Creation-Tools"
    $updater = Join-Path $dataDir "veaf-tools-updater.exe"
    $tool = Join-Path $dataDir "veaf-tools.exe"
    $stamp = Join-Path $dataDir ".last-update"
    $throttleHours = 4

    function Get-Updater {
        $url = "https://github.com/$repo/releases/download/$tag/veaf-tools-updater.exe"
        Invoke-WebRequest -Uri $url -OutFile $updater -UseBasicParsing
    }

    if (-not (Test-Path $tool)) {
        # First launch: install synchronously so the MCP has a binary to run. The updater installs
        # into its CURRENT directory, so run it from the data dir (not wherever the hook's cwd is).
        Get-Updater
        Push-Location $dataDir
        try { & $updater --tag $tag } finally { Pop-Location }
        Set-Content -Path $stamp -Value (Get-Date -Format o)
        exit 0
    }

    # Already installed: refresh at most once per throttle window, detached.
    $fresh = (Test-Path $stamp) -and `
        (((Get-Date) - (Get-Item $stamp).LastWriteTime).TotalHours -lt $throttleHours)
    if (-not $fresh) {
        if (-not (Test-Path $updater)) { Get-Updater }
        Start-Process -FilePath $updater -ArgumentList @("--tag", $tag) `
            -WorkingDirectory $dataDir -WindowStyle Hidden
        Set-Content -Path $stamp -Value (Get-Date -Format o)
    }
    exit 0
}
catch {
    # Never block the session on an update failure.
    Write-Error "veaf-mission-editor bootstrap: $($_.Exception.Message)"
    exit 0
}
