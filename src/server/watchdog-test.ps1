$ProcessName = "DCS"
$WindowTitle = "private_server_2.5.6"
$ExePath = "notepad.exe"
$CommandLine = " test.txt"
$WebHookOnFailure = "C:\Users\veaf\webhookAlerter.ps1"
$Affinity = 5 # cores 0 and 2
$Priority = "HIGH"

C:/Users/veaf/watchdogProcess.ps1 -ProcessName $ProcessName -WindowTitle $WindowTitle -ExePath $ExePath -CommandLine $CommandLine -WebHookOnFailure $WebHookOnFailure -Priority $Priority -Affinity $Affinity