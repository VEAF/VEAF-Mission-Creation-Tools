Function Set-PSAffinity
{
<#  
  .SYNOPSIS   
   Set the processor affinity of the current Powershell session
  .PARAMETER core
   The core thread that is allowed to run this process.  Separate each core with a comma. e.g. 1,3
  .PARAMETER all
   if specified, all cores are allowed.
  .EXAMPLE  
   Set-PSAffinity -core 2 
  .EXAMPLE  
   Set-PSAffinity -core 1,3,5 
  .EXAMPLE  
   Set-PSAffinity -all
#> 
param (
$core,
[switch]$all
)

[int]$LogicalProcessors = 0
Get-WmiObject -class win32_processor | ForEach-Object { $LogicalProcessors += $_.NumberOfLogicalProcessors}
$maxaffinity = ([math]::pow(2,$LogicalProcessors) - 1)

if ($core) { $core | Select-Object -unique |  ForEach-Object  {$affinity = 0} {$affinity += [math]::pow(2,$_-1) } }
if ($all) { $affinity = $maxaffinity }
if (($affinity -gt $maxaffinity) -or ($affinity -lt 1)) {$affinity = $maxaffinity}

(Get-Process -id $pid).processoraffinity = [int]$affinity
	
}
