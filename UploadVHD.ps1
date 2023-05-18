
# Connect to Azure
Write-Host "Connect to Azure US Gov?"
$response = Read-Host "Y or N"
$response.ToUpper()
If($response -eq 'Y'){ $Environment = "AzureUSGovernment"}
else{$Environment = "AzureCloud"}

Connect-AzAccount -Environment $Environment

$Subs = Get-AzSubscription
If($Subs.count -gt 1){
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }
}
$Selection = Read-Host "Subscription"
$Selection = $Subs[$Selection-1]
Select-AzSubscription -SubscriptionObject $Selection

# Get required parameters
$Path = Read-Host "Path and file name of the VHD to be uploaded? (i.e. C:\temp\myimage.vhd or \\fileserver\share1\image.vhd)"
$resourceGroup = Read-Host "Resource Group name to create and upload managed disk to"
$name = Read-Host "Desired Name for Managed Disk to be created"

$location = (Get-AzResourceGroup -Name $resourceGroup).Location

# To use $Zone or #sku, add -Zone or -DiskSKU parameters to the command
Write-Host "Creating New Empty Azure Managed Disk that will be used as target for image."
Add-AzVhd -LocalFilePath $path -ResourceGroupName $resourceGroup -Location $location -DiskName $name