#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory, Position=0)]
    [string] $ProcessName,

    [Parameter(Mandatory, Position=1)]
    [string] $WindowTitle,

    [Parameter(Mandatory, Position=2)]
    [string] $ExePath,

    [Parameter(Mandatory, Position=3)]
    [string] $CommandLine,

    [Parameter(Mandatory, Position=4)]
    [string] $WebHookOnFailure,
	
    [Parameter(Mandatory, Position=5)]
    [string] $Priority,

    [Parameter(Mandatory, Position=6)]
    [string] $LogfileName,

    [Parameter(Mandatory, Position=7)]
    [string] $InitialDelay,

    [Parameter(Mandatory, Position=7)]
    [string] $WatchdogDelay
)

$LogPath = join-path (Get-Location) ("logs\watchdog-" + $LogfileName + ".log")

#Called when a crash is detected. You can write out to a log or call a discord webhook.
function onCrash {
    if (test-path $WebHookOnFailure) {
        if ($hangcount -ge 5) {
            & $WebHookOnFailure Error "watchdogProcess" "Process $ProcessName $WindowTitle is frozen, restarting..."
        }
        else {
            & $WebHookOnFailure Warning "watchdogProcess" "Process $ProcessName $WindowTitle is not running (crashed?), restarting..."
        }
    }
}

function StartProcess {
    write-host "Starting $ProcessName"
	Add-Content -Path $LogPath -Value ((Get-Date -Format s) + " - Starting Process " + $ProcessName)
	$priorityValues = "LOW", "NORMAL", "HIGH", "REALTIME", "ABOVENORMAL", "BELOWNORMAL" # Remove ABOVENORMAL and BELOWNORMAL if running on Win98 or WinME
	$priorityUC = $Priority.ToUpper()
	write-host "$priorityUC $ExePath $CommandLine"
    If($priorityValues -contains $priorityUC)
    {
		Try
		{
			$pinfo = New-Object System.Diagnostics.ProcessStartInfo
			$pinfo.FileName = $ExePath
			$pinfo.Arguments = $CommandLine
			$p = New-Object System.Diagnostics.Process
			$p.StartInfo = $pinfo
			$p.Start()
			$p.PriorityClass=$priorityUC
		}
		Catch
		{
			$exceptionMessage = $_.Exception.Message
			Write-Host "An exception:`n`n$exceptionMessage`n`noccured!" -fore white -back red  # Uncomment for console errors
			#[System.Windows.Forms.MessageBox]::Show("An exception:`n`n$exceptionMessage`n`noccured!", "An Exception Occured", "Ok", "Error");
			Break
		}
	}
	Else
    {
        Write-Host "The priority: `"$priorityUC`" is not a valid priority value!" -fore white -back red    # Uncomment for console errors
        #[System.Windows.Forms.MessageBox]::Show("The priority: `"$priorityUC`" is not a valid priority value!", "A Priority Error Occured", "Ok", "Error");
    }
	write-host "Waiting " $InitialDelay " seconds for $ProcessName"
	Start-Sleep $InitialDelay
}

$hangcount = 0
$waitTime = $WatchdogDelay

$wasRunning = $false

while ($true) {
    $process = Get-Process $ProcessName -ErrorAction SilentlyContinue | where {$_.mainWindowTItle -match $WindowTitle }
	if ($process) {
		write-host ("Process " + $ProcessName + " found.")
	}
    if ($process.Responding) {
        write-host ("Process " + $ProcessName + " found and running. Checking again in $waitTime seconds.")

        if ($hangcount -gt 0) {
            Add-Content -Path $LogPath -Value ("Recovered at " + (Get-Date -Format s) + " after $hangcount")
        }

        $hangcount = 0
        $wasRunning = $true
        Start-Sleep $waitTime
    }
    elseif ($hangcount -ge 10) {
        write-host ($ProcessName + " is not responding, restarting it")
		Add-Content -Path $LogPath -Value ((Get-Date -Format s) + " - Process " + $ProcessName + " is not responding, restarting it")
        onCrash
        Stop-Process $process
        Start-Sleep 15
        $hangcount = 0
        StartProcess
    }
    elseif ($process -and $hangcount -gt 0) {
        $hangcount++
        write-host "Process $ProcessName still not responding. Hang counter at $hangcount"
		Add-Content -Path $LogPath -Value ((Get-Date -Format s) + " - Process " + $ProcessName + " still not responding. Hang counter at " + $hangcount)
        Start-Sleep $waitTime
    }
    elseif ($process -and $hangcount -lt 3) {
        write-host "Process $ProcessName found, but not responding"
		Add-Content -Path $LogPath -Value ((Get-Date -Format s) + " - Process " + $ProcessName + " found, but not responding")
        $hangcount++
        Start-Sleep $waitTime
    }
    else {
        write-host "Process $ProcessName is not running.."
		Add-Content -Path $LogPath -Value ((Get-Date -Format s) + " - Process " + $ProcessName + " is not running..")
        if ($wasRunning) {
            write-host ("Looks like we crashed... calling onCrash.")
            onCrash
            $wasRunning = $false
        }
        StartProcess
    }
}
