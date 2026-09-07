<#
.SYNOPSIS
    Start the VEAF support bot with the settings written in a .env file.

.DESCRIPTION
    The service reads its configuration from the **environment** and never from a file — that is a
    decision of its own (`veaf_support_bot/config.py`), and it is why the container is started with
    `--env-file`. A direct run has no such flag, so the README's instructions set the variables one
    by one, which is fine for a rehearsal and unusable at boot.

    This script is the missing half: it reads the same `.env` the container would, puts it in the
    environment of one process, and starts the module. Nothing else. In particular it does **not**
    write the values anywhere, and it does not touch the machine's own environment — a leaked bot
    token is a bot somebody else owns.

.PARAMETER EnvFile
    The settings file. Defaults to `.env` beside the service.

.PARAMETER Python
    The interpreter to run. Defaults to `poetry run python`, which is what a development machine
    has. A deployment that has no Poetry passes the python of its own virtual environment, e.g.
    `-Python C:\veaf\bot\.venv\Scripts\python.exe`.

.PARAMETER Healthcheck
    Probe a running service instead of starting one, and exit with its verdict. This is what a
    scheduled task or an uptime monitor calls.

.EXAMPLE
    .\scripts\run.ps1
    Start it here, reading .env, with Poetry.

.EXAMPLE
    .\scripts\run.ps1 -Python C:\veaf\bot\.venv\Scripts\python.exe
    What the scheduled task on dcs.veaf.org runs at boot.

.NOTES
    Exit code 78 (EX_CONFIG) means the configuration is wrong and restarting will not help; the
    message above it lists every problem at once. Any other non-zero code is a crash.
#>
[CmdletBinding()]
param(
    [string] $EnvFile = (Join-Path $PSScriptRoot '..\.env'),
    [string] $Python = '',
    [switch] $Healthcheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$service = Resolve-Path (Join-Path $PSScriptRoot '..')

function Import-DotEnv {
    <#
    .SYNOPSIS
        Read a KEY=VALUE file into the current process's environment.
    .DESCRIPTION
        Deliberately literal: no interpolation, no command substitution, no `export`. A value is
        everything after the first `=`, trimmed of one matching pair of surrounding quotes — which
        is what Docker's own --env-file does, and what somebody pasting a PEM or a token expects.

        A malformed line is reported **by its line number and nothing else**. Never its content:
        this file holds a bot token and a private key, PowerShell sends warnings to stderr, and the
        documented way to run this at boot redirects stderr to a log nobody treats as a secret. An
        earlier version interpolated the line — measured in review, pasting a multi-line PEM wrote
        its body into that log, one warning per line.

        A name that is not a variable name is refused for the same reason: a base64 line whose
        padding contains `=` parses as an assignment, and `SetEnvironmentVariable` would then create
        a variable *named* after key material.
    #>
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "no settings file at $Path — copy .env.example to .env and fill it in"
    }

    $loaded = 0
    $line = 0
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line++
        $text = $raw.Trim()
        if ($text.Length -eq 0 -or $text.StartsWith('#')) { continue }
        # Before the split, not after: a `-----BEGIN …` line holds no `=` at all, so a guard placed
        # after would never see the one mistake it exists for. Refusing here also stops the parse
        # before the body of the key, whose base64 padding would otherwise read as an assignment.
        if ($text.StartsWith('-----BEGIN')) {
            Write-Error ("${Path} line ${line}: a PEM cannot be pasted across lines in this file. " +
                'Put the key in a file of its own and point SUPPORT_BOT_GITHUB_PRIVATE_KEY_FILE ' +
                'at it, or use SUPPORT_BOT_GITHUB_PRIVATE_KEY with literal \n escapes on one line.')
        }
        $split = $text.IndexOf('=')
        if ($split -lt 1) {
            Write-Warning "${Path} line ${line}: no '=' — ignored (content not shown)"
            continue
        }
        $name = $text.Substring(0, $split).Trim()
        $value = $text.Substring($split + 1).Trim()
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            Write-Warning "${Path} line ${line}: not a variable name — ignored (content not shown)"
            continue
        }
        if ($value.Length -ge 2 -and
            (($value.StartsWith('"') -and $value.EndsWith('"')) -or
             ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        # Process scope only: this must not survive the process, and must not reach the user's own
        # environment where every other program could read the bot token.
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        $loaded++
    }
    Write-Host "loaded $loaded setting(s) from $Path"
}

Import-DotEnv -Path $EnvFile

$arguments = @('-m', 'veaf_support_bot')
if ($Healthcheck) { $arguments += '--healthcheck' }

if ([string]::IsNullOrWhiteSpace($Python)) {
    Push-Location $service
    try {
        & poetry run python @arguments
    }
    finally {
        Pop-Location
    }
}
else {
    if (-not (Test-Path -LiteralPath $Python)) {
        Write-Error "no interpreter at $Python"
    }
    # PYTHONPATH rather than a working directory: an installed deployment has the package on the
    # path already, and a source one has it here. Setting both costs nothing and makes the script
    # work before `pip install -e .` has ever been run.
    $env:PYTHONPATH = "$service;$($env:PYTHONPATH)"
    & $Python @arguments
}

exit $LASTEXITCODE
