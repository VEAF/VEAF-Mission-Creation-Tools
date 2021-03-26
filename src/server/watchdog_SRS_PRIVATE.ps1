#XXXRequires -RunAsAdministrator


$ProcessName = "SR-Server"
$WindowTitle = "DCS-SRS Server - 1.9.5.0 - 5102"
$LogfileName = "SRS-private"
$ExePath = "C:\Program Files\DCS-SimpleRadio-Standalone\SR-Server.exe"
$CommandLine = ' -cfg="C:\Users\veaf\Saved Games\private_server_2.5.6\DCS-SimpleRadio-Standalone\server.cfg"'
$WebHookOnFailure = " "
$Priority = "NORMAL"
$InitialDelay = 15
$WatchdogDelay = 30

C:/Users/veaf/watchdogProcess.ps1 -ProcessName $ProcessName -WindowTitle $WindowTitle -ExePath $ExePath -CommandLine $CommandLine -WebHookOnFailure $WebHookOnFailure -Priority $Priority -LogfileName $LogfileName -InitialDelay $InitialDelay -WatchdogDelay $WatchdogDelay
