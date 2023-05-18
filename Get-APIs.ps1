connect-azaccount
get-azsubscription
set-azcontext -subscription 8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9

connect-azaccount -Environment AzureUSGovernment


Class AzAPIs{
    [string]$ResourceTypeName
    [string]$cloud
    [string]$latestAPI
	[array] $availableAPIs
    [array] $locations
}

$hostPool = (Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization).ResourceTypes


$arrResources = @()
Foreach($item in $hostPool){
    $AzureGlobalobj = New-Object AzAPIs
    write-host "ResourceTypeName:" $Item.ResourceTypeName
    $AzureGlobalobj.ResourceTypeName = $item.ResourceTypeName
    $latestAPI = ($item.ApiVersions | Sort-Object)[-1]
    write-host "ApiVersions:" $latestAPI
    $AzureGlobalobj.latestAPI = $latestAPI
    $AzureGlobalobj.availableAPIs = $item.ApiVersions
    $AzureGlobalobj.locations = $item.Locations
    $AzureGlobalobj.cloud = "AzureCloud"
    Write-Host "Writing to object: " $AzureGlobalobj
    $arrResources += $AzureGlobalobj
    }

connect-azaccount -Environment AzureUSGovernment

$arrGovResources = @()
Foreach($item in $hostPool){
    $AzureGlobalobj = New-Object AzAPIs
    write-host "ResourceTypeName:" $Item.ResourceTypeName
    $AzureGlobalobj.ResourceTypeName = $item.ResourceTypeName
    $latestAPI = ($item.ApiVersions | Sort-Object)[-1]
    write-host "ApiVersions:" $latestAPI
    $AzureGlobalobj.latestAPI = $latestAPI
    $AzureGlobalobj.availableAPIs = $item.ApiVersions
    $AzureGlobalobj.locations = $item.Locations
    $AzureGlobalobj.cloud = "AzureUSGovernment"
    Write-Host "Writing to object: " $AzureGlobalobj
    $arrGovResources += $AzureGlobalobj
    }

    $a = $arrResources[0].availableAPIs + $arrGovResources[0].availableAPIs
    Compare-Object -DifferenceObject $arrResources[0].availableAPIs -ReferenceObject $arrGovResources[0].availableAPIs -ExcludeDifferent

$b = $a | Select-Object availableAPIs -Unique
Compare-Object -Property availableAPIs -ReferenceObject $a -DifferenceObject $b -PassThru | Select-Object * -ExcludeProperty SideIndicator