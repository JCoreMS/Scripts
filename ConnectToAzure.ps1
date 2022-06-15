Write-Host "Connect to Azure US Gov?"
$response = Read-Host "Y or N"
$response.ToUpper()
If($response -eq 'Y'){ $Environment = "AzureUSGovernment"}
else{$Environment = "AzureCloud"}

Connect-AzAccount -Environment $Environment

$Subs = Get-AzSubscription
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }

$Selection = Read-Host "Subscription"
$Selection = $Subs[$Selection-1]
Select-AzSubscription -SubscriptionObject $Selection

# ----------------------------------------------------------------

$Deployment = "C:\GitRepo\AVDAlerts\solution.bicep"
$paramFile = "C:\GitRepo\AVDAlerts\parameters.json"

New-AzDeployment `
  -Name "TEST"  `
  -Location "East US 2" `
  -TemplateFile "C:\GitRepo\AVDAlerts\temp.bicep"

New-AzDeployment `
  -Name "AVD-Alerts-Solution" `
  -TemplateParameterFile $paramfile `
  -Location "East US 2" `
  -TemplateFile $Deployment


<#
/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Identity/providers/Microsoft.KeyVault/vaults/kv-eastus2-AVD-SSO-Certs
https://kv-eastus2-avd-sso-certs.vault.azure.net/secrets/MSIXAppAttachLab/b1446c7025ce43839c1ce594770b7c84
yEXpE5kbO+kHQ0dqv0BiQ46k5BcifAvPpenJxfvTwRn+giJq/CvoEjNGbhIVjjM3rpLmSnNdD7IsJ2R8t7TKxA==
#>
