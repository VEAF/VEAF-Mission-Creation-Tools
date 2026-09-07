<#
.SYNOPSIS
    Fill in a local `.env` for the support bot, and set the shared secret on the Worker.

.DESCRIPTION
    Everything this service needs to start is a value somebody has to fetch from a console: a bot
    token from Discord, two numbers from a GitHub App, a private key file, and a password shared
    with the documentation Worker. This script asks for them and writes them where they belong.

    **The secrets are typed here and never displayed.** The bot token is read masked, and the shared
    Worker secret is *generated* rather than asked for — nobody has to see it, since the only two
    places it has to match are the two this script writes it to. What ends up on screen is a list of
    which settings are now present, never a value.

    Two of the five are not secret and are read in the clear on purpose: a guild id and an App id are
    public numbers, and masking them only makes a typo harder to spot.

    Re-running it is safe: a setting that already has a value is left alone unless `-Force` is given.

.PARAMETER EnvFile
    The file to write. Defaults to `.env` beside the service.

.PARAMETER SkipWorkerSecret
    Do not touch the Worker. Use this when the shared secret is already set on both sides, or when
    you are not the one who administers Cloudflare.

.PARAMETER Force
    Overwrite settings that already have a value.

.EXAMPLE
    .\scripts\setup-local.ps1
    Ask for what is missing, generate the shared secret, set it on the Worker, write .env.

.NOTES
    The Worker secret is written with `npx wrangler secret put DISCORD_CLIENT_SECRET`, which needs
    you to be logged in (`npx wrangler whoami`). That name has nothing to do with Discord's own
    client secret — see README, "The other half: the Worker Secret".
#>
[CmdletBinding()]
param(
    [string] $EnvFile = (Join-Path $PSScriptRoot '..\.env'),
    [switch] $SkipWorkerSecret,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$service = Resolve-Path (Join-Path $PSScriptRoot '..')
$repository = Resolve-Path (Join-Path $service '..\..')

function Get-Setting {
    <#
    .SYNOPSIS
        Return the value a setting currently holds in the file, or an empty string.
    #>
    param([AllowEmptyString()] [string[]] $Lines, [Parameter(Mandatory)] [string] $Name)

    foreach ($line in $Lines) {
        if ($line -match "^$([regex]::Escape($Name))=(.*)$") { return $Matches[1] }
    }
    return ''
}

function Set-Setting {
    <#
    .SYNOPSIS
        Replace one setting's value in the file's lines, in place.
    .DESCRIPTION
        The line is rewritten rather than appended, so the file keeps the comments that explain each
        setting — they are the only documentation the operator has in front of him.
    #>
    param(
        [AllowEmptyString()] [string[]] $Lines,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Value
    )

    $written = $false
    $result = foreach ($line in $Lines) {
        if (-not $written -and $line -match "^$([regex]::Escape($Name))=") {
            $written = $true
            "$Name=$Value"
        }
        else { $line }
    }
    if (-not $written) { $result += "$Name=$Value" }
    return $result
}

function Test-Placeholder {
    <#
    .SYNOPSIS
        Say whether a value is absent in practice: empty, or the example file's own stand-in.
    .DESCRIPTION
        `.env.example` ships readable stand-ins — `put-the-bot-token-here`, `000000000000000000` —
        and treating one as a real value is worse than treating it as missing: the script would
        report the setting as done and the service would start with a token Discord refuses. Found
        by running this script against a fresh copy of the example file.
    #>
    param([AllowEmptyString()] [string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value -match '^(put-|change-|your-|xxx|<)') -or ($Value -match '^0+$')
}

function Read-Secret {
    <#
    .SYNOPSIS
        Read one value without echoing it, and without leaving it in a shell history.
    #>
    param([Parameter(Mandatory)] [string] $Prompt)

    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Copy-Item -LiteralPath (Join-Path $service '.env.example') -Destination $EnvFile
    Write-Host "created $EnvFile from .env.example"
}
$lines = @(Get-Content -LiteralPath $EnvFile -Encoding UTF8)

# --- the values a console gives you ------------------------------------------
$asked = @(
    @{ Name = 'SUPPORT_BOT_DISCORD_TOKEN'; Prompt = 'Discord bot token (Bot > Reset Token)'; Secret = $true },
    @{ Name = 'SUPPORT_BOT_DISCORD_GUILD_ID'; Prompt = 'VEAF guild id (right-click the server > Copy Server ID)'; Secret = $false },
    @{ Name = 'SUPPORT_BOT_GITHUB_APP_ID'; Prompt = 'GitHub App id (App settings > General > App ID)'; Secret = $false },
    @{ Name = 'SUPPORT_BOT_GITHUB_INSTALLATION_ID'; Prompt = 'Installation id (the number at the end of the Configure URL)'; Secret = $false }
)

foreach ($item in $asked) {
    $current = Get-Setting -Lines $lines -Name $item.Name
    if (-not (Test-Placeholder -Value $current) -and -not $Force) {
        Write-Host "$($item.Name): already set, left alone"
        continue
    }
    $value = if ($item.Secret) { Read-Secret -Prompt $item.Prompt } else { Read-Host -Prompt $item.Prompt }
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Warning "$($item.Name): nothing entered, left as it was"
        continue
    }
    $lines = Set-Setting -Lines $lines -Name $item.Name -Value $value.Trim()
    Write-Host "$($item.Name): set"
}

# --- the App's private key ---------------------------------------------------
$keyTarget = Get-Setting -Lines $lines -Name 'SUPPORT_BOT_GITHUB_PRIVATE_KEY_FILE'
if ($keyTarget -and -not (Test-Path -LiteralPath $keyTarget)) {
    Write-Host ''
    Write-Host "The App's private key is expected at: $keyTarget"
    $source = Read-Host -Prompt 'Path to the .pem you downloaded (empty to skip)'
    if (-not [string]::IsNullOrWhiteSpace($source)) {
        $source = $source.Trim('"').Trim()
        if (Test-Path -LiteralPath $source) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $keyTarget) | Out-Null
            Copy-Item -LiteralPath $source -Destination $keyTarget -Force
            Write-Host "key copied to $keyTarget"
        }
        else { Write-Warning "no file at $source — the key is still missing" }
    }
}

# --- the secret shared with the Worker ---------------------------------------
# Generated, not asked: the only two places it has to match are the two written here, so nobody
# needs to read it, paste it, or keep it. A lost one is replaced the same way.
$workerSecret = Get-Setting -Lines $lines -Name 'SUPPORT_BOT_WORKER_SECRET'
if ((Test-Placeholder -Value $workerSecret) -or $Force) {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $workerSecret = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $lines = Set-Setting -Lines $lines -Name 'SUPPORT_BOT_WORKER_SECRET' -Value $workerSecret
    Write-Host 'SUPPORT_BOT_WORKER_SECRET: generated'

    if (-not $SkipWorkerSecret) {
        Write-Host ''
        Write-Host 'The Worker refuses this bot until the same value is set on its side, as'
        Write-Host 'DISCORD_CLIENT_SECRET. That is an outbound change to a deployed service.'
        $answer = Read-Host -Prompt 'Set it on the Worker now? (y/N)'
        if ($answer -eq 'y') {
            $worker = Join-Path $repository 'poc\doc-chatbot\worker'
            Push-Location $worker
            try {
                # Through stdin: the value never appears in a command line, where it would be
                # visible in the process list and kept in a shell history.
                $workerSecret | & npx wrangler secret put DISCORD_CLIENT_SECRET
                if ($LASTEXITCODE -ne 0) { Write-Warning 'wrangler refused; the bot will not be able to ask the documentation' }
                else { Write-Host 'the Worker now shares the secret' }
            }
            finally { Pop-Location }
        }
        else {
            Write-Host 'skipped. Until it is set, /ask answers that the assistant refuses this bot.'
        }
    }
}
else {
    Write-Host 'SUPPORT_BOT_WORKER_SECRET: already set, left alone'
}

Set-Content -LiteralPath $EnvFile -Value $lines -Encoding UTF8

# --- what is still missing, by name -----------------------------------------
Write-Host ''
$required = @(
    'SUPPORT_BOT_DISCORD_TOKEN',
    'SUPPORT_BOT_DISCORD_GUILD_ID',
    'SUPPORT_BOT_WORKER_SECRET',
    'SUPPORT_BOT_GITHUB_APP_ID',
    'SUPPORT_BOT_GITHUB_INSTALLATION_ID'
)
$lines = @(Get-Content -LiteralPath $EnvFile -Encoding UTF8)
$missing = @($required | Where-Object { Test-Placeholder -Value (Get-Setting -Lines $lines -Name $_) })
if ($keyTarget -and -not (Test-Path -LiteralPath $keyTarget)) { $missing += 'the private key file' }

if ($missing.Count -eq 0) {
    Write-Host 'Everything is set. Start it with:  .\scripts\run.ps1'
}
else {
    Write-Host 'Still missing:'
    $missing | ForEach-Object { Write-Host "  - $_" }
}
