$env:SYSTEM_TEAMPROJECT = "yourProject"
$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = "https://account.visualstudio.com/"
$env:PersonalAccessToken="your PAT"
$env:Build_BuildID = #BuildID



Set-Location $PSScriptRoot

. .\CheckBuildChanged.ps1 -localRun -outputvariableName test -setBuildTag $true -buildTagList "A;B;C" 

Invoke-CheckBuildChanged 
