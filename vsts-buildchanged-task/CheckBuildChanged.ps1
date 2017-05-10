[cmdletbinding()]
param
(
    [string] $outputVarBuildResult,
    [string] $tagsBuildChanged,
    [string] $tagsBuildNotChanged,
    [switch] $localRun
)

#global variables
$baseurl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI 
$baseurl += $env:SYSTEM_TEAMPROJECT + "/_apis"

Write-Debug  "baseurl=$baseurl"

function Get-BuildDefinition
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $BuildDefinitionName=""
    )

    $bdURL = "$baseurl/build/definitions?api-version=2.0"
    Write-Verbose "bdURL: $bdURL"
    
    $cred = Get-VstsTfsClientCredentials
    $response = Invoke-RestMethod -Uri $bdURL -Method Get -Credential $cred
    $buildDef = $response.value | Where-Object {$_.name -eq $BuildDefinitionName} | select -First 1
    Write-Verbose "Build Definition: $buildDef"
    return $buildDef
}

function Get-BuildById
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [int] $BuildId
    )

    $cred = Get-VstsTfsClientCredentials
    $bdURL = "$baseurl/build/builds/$BuildId"
    
    $response = Invoke-RestMethod -Uri $bdURL -Method Get -Credential $cred
    return $response
}

<#
.Synopsis
Sets a Build Tag on a specific BuildID. Semicolon separates multiple Build Tags (e.g. Test;TEST2;Ready)
#>
function Set-BuildTag
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $BuildID="",
        [string] $BuildTags=""
    )
    if ($BuildTags -eq "") {
        return
    }

    $buildTagsArray = $BuildTags.Split(";");
    $cred = Get-VstsTfsClientCredentials


    Write-Verbose "BaseURL: [$baseurl]"
    Write-Verbose "tagURL: [$tagURL]"
    Write-Verbose "token: [$token]"

    if ($buildTagsArray.Count -gt 0) 
    {

        foreach($tag in $buildTagsArray)
        {
            $tagURL = "$baseurl/build/builds/$BuildID/tags/$tag`?api-version=2.0"
            $response = Invoke-RestMethod -Uri $tagURL  -Method Put -Credential $cred
        }   
    }
}


<#
.Synopsis
Gets builds with a specific Tag. Semicolon separates multiple Build Tags (e.g. Test;TEST2;Ready)
#>
function Get-BuildsByDefinition
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [int] $BuildDefinitionID
    )
    
    $cred = Get-VstsTfsClientCredentials
    
    $buildsbyDefinitionURL = "$baseurl/build/builds?definitions=$BuildDefinitionID&api-version=2.0"

    $_builds = Invoke-RestMethod -Uri $buildsbyDefinitionURL  -Method Get -ContentType "application/json" -Credential $cred
    Write-Verbose "Builds $_builds"
    return $_builds
}


function Invoke-CheckBuildChanged
{
    if ($env:Build_BuildID -eq $null )
    {
        Write-Error "Error retrieving BuildID"
    }

    $currentBuildID = $env:Build_BuildID
    $CurrentBuild = Get-BuildById -BuildId $currentBuildID
    $builds = Get-BuildsByDefinition -BuildDefinitionID $CurrentBuild.definition[0].id

    $LatestBuild = $builds.value | Where-Object {$_.result -eq "succeeded"} |Sort-Object {$_.finishtime} -Descending | select -First 1

    if ($LatestBuild -eq $null)
    {
        #No successfull builds found, thus different commit"
        Set-BuildTag -BuildID $currentBuildID -BuildTags $tagsBuildChanged
        Write-Host "No successfull builds found, thus different commit"
        Write-Host "##vso[task.setvariable variable=$($outputVarBuildResult);]true"

    }

    if ($LatestBuild.sourceVersion -ne $CurrentBuild.sourceVersion)
    {
        # Not the same, tag with a Release Tag
        Set-BuildTag -BuildID $currentBuildID -BuildTags $tagsBuildChanged 
        Write-Host "Build changed, setting outputvariable to true"
        Write-Host "##vso[task.setvariable variable=$($outputVarBuildResult);]true"

    }
    else 
    {
        Set-BuildTag -BuildID $currentBuildID -BuildTags $tagsBuildNotChanged 
        Write-Host "Build not changed, setting outputvariable to false"
        Write-Host "##vso[task.setvariable variable=$($outputVarBuildResult);]false"

    }
}

if (-not $localRun) 
{
    Invoke-CheckBuildChanged
}

