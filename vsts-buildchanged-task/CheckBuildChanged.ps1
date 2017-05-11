[CmdletBinding()]
param()

$outputVarBuildResult = Get-VstsInput -Name outputVarBuildResult
$tagsBuildChanged = Get-VstsInput -Name tagsBuildChanged
$tagsBuildNotChanged =Get-VstsInput -Name tagsBuildNotChanged


#global variables
$baseurl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI 
$baseurl += $env:SYSTEM_TEAMPROJECT + "/_apis"

Write-Debug  "baseurl=$baseurl"
Write-Host  "VSTS EndPoint=$connectedServiceName"

function InitializeRestHeaders()
{
	$restHeaders = New-Object -TypeName "System.Collections.Generic.Dictionary[[String], [String]]"
	if([string]::IsNullOrWhiteSpace($connectedServiceName))
	{
		$patToken = GetAccessToken $connectedServiceDetails
		ValidatePatToken $patToken
		$restHeaders.Add("Authorization", [String]::Concat("Bearer ", $patToken))
		
	}
	else
	{
		$Username = $connectedServiceDetails.Authorization.Parameters.Username
		Write-Verbose "Username = $Username" -Verbose
		$Password = $connectedServiceDetails.Authorization.Parameters.Password
		$alternateCreds = [String]::Concat($Username, ":", $Password)
		$basicAuth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($alternateCreds))
		$restHeaders.Add("Authorization", [String]::Concat("Basic ", $basicAuth))
	}
	return $restHeaders
}

function GetAccessToken($vssEndPoint) 
{
        $endpoint = (Get-VstsEndpoint -Name SystemVssConnection -Require)
        $vssCredential = [string]$endpoint.auth.parameters.AccessToken	
        return $vssCredential
}

function ValidatePatToken($token)
{
	if([string]::IsNullOrWhiteSpace($token))
	{
		throw "Unable to generate Personal Access Token for the user. Contact Project Collection Administrator"
	}
}

function Get-BuildDefinition
{
    [CmdletBinding()]
    [OutputType([object])]
    param
    (
        [string] $BuildDefinitionName=""
    )

    $token = New-VSTSAuthenticationToken
    $bdURL = "$baseurl/build/definitions?api-version=2.0"
    Write-Verbose "bdURL: $bdURL"
    
    
    $response = Invoke-RestMethod -Uri $bdURL -Method Get -Headers $headers
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

    $token = New-VSTSAuthenticationToken
    $bdURL = "$baseurl/build/builds/$BuildId"
    
    $response = Invoke-RestMethod -Uri $bdURL -Method Get -Headers $headers
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

    $token = New-VSTSAuthenticationToken
    $buildTagsArray = $BuildTags.Split(";");


    Write-Verbose "BaseURL: [$baseurl]"
    Write-Verbose "tagURL: [$tagURL]"
    Write-Verbose "token: [$token]"

    if ($buildTagsArray.Count -gt 0) 
    {

        foreach($tag in $buildTagsArray)
        {
            $tagURL = "$baseurl/build/builds/$BuildID/tags/$tag`?api-version=2.0"
            $response = Invoke-RestMethod -Uri $tagURL  -Method Put -Headers $headers
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
    
    $token = New-VSTSAuthenticationToken
    $buildsbyDefinitionURL = "$baseurl/build/builds?definitions=$BuildDefinitionID&api-version=2.0"

    $_builds = Invoke-RestMethod -Uri $buildsbyDefinitionURL  -Method Get -ContentType "application/json" -Headers $headers
    Write-Verbose "Builds $_builds"
    return $_builds
}


function Invoke-CheckBuildChanged
{
    [CmdletBinding()]
    [OutputType([object])]
    param()


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

$headers=InitializeRestHeaders
Invoke-CheckBuildChanged