Connect-AzAccount
Get-AzSubscription
Set-AzContext -Subscription ''

#=================================================================================
#                                PRE-REQs
#=================================================================================
# Register for Azure Image Builder Feature
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages

Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
# wait until RegistrationState is set to 'Registered'

# check you are registered for the providers, ensure RegistrationState is set to 'Registered'.
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault

# If they do not show registered, run the commented out code below.

## Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
## Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
## Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
## Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault


#=================================================================================
#                      Setup Environment and Variables
#=================================================================================
# Step 1: Import module
Import-Module Az.Accounts

# Step 2: get existing context
$currentAzContext = Get-AzContext

# destination image resource group
$imageResourceGroup="rg-eastus2-AVDLab-AIB"

# location (see possible locations in main docs)
$location="eastus2"

# your subscription, this will get your current subscription
$subscriptionID=$currentAzContext.Subscription.Id

# image template name
$imageTemplateName="avd10ImageTemplateOffice"

# distribution properties object name (runOutput), i.e. this gives you the properties of the managed image on completion
$runOutputName="sigOutput"

# create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location

# Azure Compute Gallery Name
$sigGalleryName= "AIB_AVD"  # Underscore and periods / no dashes

# Azure Compute Gallery Image Definition Name
$imageDefName ="win10avd-Office"

# Company name to be used for Publisher for Image Definition
$CompanyName = "Contoso"
$VMGen = "v2"

#=================================================================================
#           Permissions, create user idenity and role for AIB                   
#=================================================================================

##  CREATE USER IDENTITY

# setup role def names, these need to be unique
$timeInt=$(get-date -Format "MMddyyHHMMss")
$imageRoleDefName="Azure Image Builder Image Def "+$timeInt
$idenityName="aibIdentity"+$timeInt

## Add AZ PS modules to support AzUserAssignedIdentity and Az AIB
# If AllowPrerelease invalid param - force update of PowerShellGet module (Must run elevated)
# Update-Module PowerShellGet -Force -Verbose   
# Install-Module PowerShellGet -AllowClobber -Force -Verbose  (in the event module not installed via install-module)
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease -Force -Verbose}

# create identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName -Location $location

$idenityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).Id
$idenityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName).PrincipalId

##  ASSIGN PERMISSIONS FOR IDENTITY TO DISTRIBUTE IMAGES
# This command will download and update the template with the parameters specified earlier.
                  
$aibRoleImageCreationUrl="https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"

# download config
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# create role definition
New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

### NOTE: If you see this error: 'New-AzRoleDefinition: Role definition limit exceeded. No more role definitions can be created.' See this article to resolve:
#   https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting

#=================================================================================
#                      Create the Shared Image Gallery             
#=================================================================================

# create gallery
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location

# create gallery definition
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType Windows -Publisher $CompanyName -Offer 'Windows' -Sku '10wvd' -HyperVGeneration $VMGen

#=================================================================================
#                    Download the Template and Configure             
#=================================================================================

<#
Multisession option example with Office

"publisher": "MicrosoftWindowsDesktop",
"offer": "office-365",
"sku": "win10-21h2-avd-m365-g2",
"version": "latest"

Single session option example

"publisher": "MicrosoftWindowsDesktop",
"offer": "Windows-10",
"sku": "19h2-ent",
"version": "latest"

Check available images:
Get-AzVMImageSku -Location $location -PublisherName MicrosoftWindowsDesktop -Offer windows-10 | select Skus
Get-AzVMImageSku -Location $location -PublisherName MicrosoftWindowsDesktop -Offer office-365 | select Skus
--- Office Offer is office-365
--- Make sure to set the image matches the VM Gen v1 or v2 (Per the created Image Definition)

Get list of VM sizes 
Get-AzVMSize -Location $location
#>


$templateUrl="https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/14_Building_Images_WVD/armTemplateWVD.json"
$templateFilePath = "armTemplateWVD.json"

Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing

((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$imageDefName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$idenityNameResourceId) | Set-Content -Path $templateFilePath

& notepad ./armTemplateWVD.json    #Review and change VM Sku and Size where appropriate

#=================================================================================
#                              Submit the Template             
#=================================================================================

New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2020-02-14" -imageTemplateName $imageTemplateName -svclocation $location -Verbose

# Optional - if you have any errors running the above, run:
$getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
$getStatus.ProvisioningErrorCode 
$getStatus.ProvisioningErrorMessage

## BUILD THE IMAGE
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -NoWait

## CHECK THE BUILD STATUS
$getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)

# this shows all the properties
$getStatus | Format-List -Property *

# these show the status the build
$getStatus.LastRunStatusRunState 
$getStatus.LastRunStatusMessage
$getStatus.LastRunStatusRunSubState




# Subnet Name:
# VNet Name:
# VNet RG: 




$location = 'eastus2'
$publisher = 'MicrosoftWindowsDesktop'
#$publisher = 'MicrosoftWindowsServer'
#$offer = 'WindowsServer'
$offer = 'office-365'
#$offer = 'windows-evd'
#$offer = 'Windows-10'
#$sku = '2022-Datacenter-g2'
#$sku = '21h1-evd-o365pp'
$sku = 'win11-21h2-avd-m365'
(Get-AzVMImagePublisher -Location $location).PublisherName
(Get-AzVMImageOffer -Location $location -PublisherName $publisher).Offer
(Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer).Skus
Get-AzVMImage -Location $location -PublisherName $publisher -Offer $offer -Skus $sku | Select-Object * | Format-List

$Temp = (Get-AzVMImageSku -Location $location -PublisherName $publisher -Offer $offer).Skus
Foreach($item in $Temp){write-host "'$item'"}