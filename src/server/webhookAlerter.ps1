param (
    [Parameter(Mandatory, Position=0)]
    [string] $Level,

    [Parameter(Mandatory, Position=1)]
    [string] $sourceOperation,

    [Parameter(Mandatory, Position=2, ValueFromRemainingArguments)]
    [string] $message
)

if (!$env:webhook_alerter_url) {
    Write-Error 'Error: Please set environment variable "webhook_alerter_url"'
    exit 1
}

$hookUrl = $env:webhook_alerter_url
[System.Collections.ArrayList]$embedArray = @()

switch ($Level) {
    "Info" { 
        $color = '8311585'
        $errorLevel = "Information"
    }
    "Error" {
        $color = '13632027' 
        $errorLevel = "Error"
    }
    "Warning" { 
        $color = '16098851' 
        $errorLevel = "Warning"
    }
    Default { exit }
}

$embedAuthor = [PSCustomObject]@{
    name = $sourceOperation
}

$embedObject = [PSCustomObject] @{
    color       = $color
    title       = $errorLevel
    description = $message
    author      = $embedAuthor
    timestamp   = Get-Date -Format "o"
}
$embedArray.Add($embedObject)


$payload = [PSCustomObject]@{
    # username = $env:COMPUTERNAME # removed, use the webhook name instead
    embeds   = $embedArray
}

Invoke-RestMethod -Uri $hookUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 4) -ContentType 'application/json'
