$ProcessName = "DCS"
$WindowTitle = "public_server_2.5.6"
$LogfileName = "DCS-public"
$ExePath = "C:\Users\veaf\refresh-opentraining-and-run-dcs.cmd"
$CommandLine = "public $WindowTitle"
$WebHookOnFailure = "C:\Users\veaf\webhookAlerter.ps1"
$Priority = "HIGH"
$InitialDelay = 30
$WatchdogDelay = 30

C:/Users/veaf/watchdogProcess.ps1 -ProcessName $ProcessName -WindowTitle $WindowTitle -ExePath $ExePath -CommandLine $CommandLine -WebHookOnFailure $WebHookOnFailure -Priority $Priority -LogfileName $LogfileName -InitialDelay $InitialDelay -WatchdogDelay $WatchdogDelay