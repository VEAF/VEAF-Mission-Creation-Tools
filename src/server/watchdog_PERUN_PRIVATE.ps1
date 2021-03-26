#XXXRequires -RunAsAdministrator


$ProcessName = "Perun"
$WindowTitle = "\[#2\] Perun for DCS - v0.11.2.0"
$LogfileName = "Perun-private"
$PerunPath = "C:\Users\veaf\PERUN"
$ExePath = $PerunPath + "\perun.exe"
$CommandLine = ' 48631 2 "C:\Users\veaf\Saved Games\private_server_2.5.6\DCS-SimpleRadio-Standalone\clients-list.json" "C:\Users\veaf\Saved Games\private_server_2.5.6\Mods\services\LotAtc\stats.json" 1'
$WebHookOnFailure = " "
$Priority = "BelowNormal"
$InitialDelay = 15
$WatchdogDelay = 30

C:/Users/veaf/watchdogProcess.ps1 -ProcessName $ProcessName -WindowTitle $WindowTitle -ExePath $ExePath -CommandLine $CommandLine -WebHookOnFailure $WebHookOnFailure -Priority $Priority -LogfileName $LogfileName -InitialDelay $InitialDelay -WatchdogDelay $WatchdogDelay
