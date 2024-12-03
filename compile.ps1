param (
    [Parameter(Mandatory, Position=0)]
    [string] $ArtefactName,
    [string] $VersionTag,
    [switch] $DevelopmentVersion = $false,
    [switch] $KeepLogging = $false,
    [switch] $DisableSecurity = $false,
    [switch] $Quiet = $false
)

Write-Host "ArtefactName: $ArtefactName"
Write-Host "VersionTag: $VersionTag"
Write-Host "DevelopmentVersion: $($DevelopmentVersion.IsPresent)"
Write-Host "KeepLogging: $($KeepLogging.IsPresent)"
Write-Host "DisableSecurity: $($DisableSecurity.IsPresent)"
Write-Host "Quiet: $($Quiet.IsPresent)"

[String[]]$VeafScripts = 
"dcsUnits.lua",
"veaf.lua",
"veafAirbases.lua",
"veafAirWaves.lua",
"veafAssets.lua",
"veafCarrierOperations.lua",
"veafCasMission.lua",
"veafCombatMission.lua",
"veafCombatZone.lua",
"veafEventHandler.lua",
"veafGrass.lua",
"veafHoundElintHelper.lua",
"veafInterpreter.lua",
"veafMarkers.lua",
"veafMissileGuardian.lua",
"veafMove.lua",
"veafNamedPoints.lua",
"veafQraManager.lua",
"veafRadio.lua",
"veafRemote.lua",
"veafSanctuary.lua",
"veafSecurity.lua",
"veafShortcuts.lua",
"veafSkynetIadsHelper.lua",
"veafSkynetIadsMonitor.lua",
"veafSpawn.lua",
"veafTime.lua",
"veafTransportMission.lua",
"veafUnits.lua",
"veafWeather.lua"

# make the build folder
if(-not $Quiet) { Write-Output "make the build folder" }
Remove-Item -Path .\build -Force -Recurse | out-null
New-Item -Path .\build -ItemType Directory -Force | out-null

# copy the scripts to the build folder
if(-not $Quiet) { Write-Output "copy the scripts to the build folder" }
Get-ChildItem -Path .\src\scripts\veaf -Recurse -Filter *.lua | Copy-Item -Destination .\build\ | out-null

# set the flags in the scripts according to the options
if(-not $Quiet) { Write-Output "set the flags in the scripts according to the options" }
$str = "veaf.Development = false"
if ($DevelopmentVersion) { 
  $str = "veaf.Development = true" 
  if ($VersionTag -eq "") { 
    $VersionTag = "-dev" 
  }
}
(Get-Content .\build\veaf.lua) -creplace "veaf.Development = (true|false)", $str | Set-Content .\build\veaf.lua
$str = "veaf.SecurityDisabled = false"
if ($DisableSecurity) { 
  $str = "veaf.SecurityDisabled = true" 
}
(Get-Content .\build\veaf.lua) -creplace "veaf.SecurityDisabled = (true|false)", $str | Set-Content .\build\veaf.lua

# comment all the trace and debug code
if (-not $DevelopmentVersion -and -not $KeepLogging) {
  if(-not $Quiet) { Write-Output "comment all the trace and debug code" }
  Get-ChildItem -Path .\build -Recurse -Filter *.lua | Foreach-Object {
     (Get-Content $_.FullName) -creplace "(^\s*)(.*veaf\.loggers.get\(.*\):(trace|debug|marker|cleanupMarkers))", "-- LOGGING DISABLED WHEN COMPILING" | 
     Set-Content -Path $_.FullName
  }
}

# compile the final artefact
if(-not $Quiet) { Write-Output "compile the final artefact" }

# create the output file
$VeafOutputFile = "veaf-scripts.lua"
if($ArtefactName -ne "") {
  $VeafOutputFile = $ArtefactName + ".lua"
}
$VeafOutputPath = ".\build\" + $VeafOutputFile
if(-not $Quiet) { Write-Output "output file will be $VeafOutputPath" }

# write the header
if(-not $Quiet) { Write-Output "write the header" }
$datetime = Get-Date -Format "yyyy.MM.dd.HH.mm.ss"
$packageJson = Get-Content .\package.json -Raw | ConvertFrom-Json 
$version = $packageJson.version
$versionMarker = "$version$VersionTag;$datetime"
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8
Write-Output "-----------------------------------------------------------------------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "-- Veaf scripts $versionMarker" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "-----------------------------------------------------------------------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append

# add the main library
if(-not $Quiet) { Write-Output "add the main library" }
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "------------------ START script veaf.lua  ------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append

Get-Content -Encoding utf8 -Path ".\build\veaf.lua" | Out-File $VeafOutputPath -Encoding utf8 -Append

Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "------------------ END script veaf.lua  ------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append

# add the other scripts
if(-not $Quiet) { Write-Output "add the other scripts" }
foreach ($script in $VeafScripts) {
  if(-not $Quiet) { Write-Output "adding script $script" }
  Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
  Write-Output "------------------ START script $script  ------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
  Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append

  Get-Content -Encoding utf8 -Path ".\build\$script" | Out-File $VeafOutputPath -Encoding utf8 -Append

  Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
  Write-Output "------------------ END script $script  ------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
  Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
}

# add the footer
if(-not $Quiet) { Write-Output "add the footer" }
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "-----------------------------------------------------------------------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "-- END OF Veaf scripts $versionMarker" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "-----------------------------------------------------------------------------------" | Out-File $VeafOutputPath -Encoding utf8 -Append
Write-Output "" | Out-File $VeafOutputPath -Encoding utf8 -Append

# copy the output file to the root folder
if(-not $Quiet) { Write-Output "copy the output file to the root folder" }
# this copies the file and also converts the shitty UTF8-with-BOM encoding to a proper UTF8 encoding (see https://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom/34969243#34969243)
$null = New-Item -Force .\published\$VeafOutputFile -Value (Get-Content -Raw $VeafOutputPath)

Write-Output "Done compiling $VeafOutputFile"