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
$paramFile = "C:\GitRepo\AVDAlerts\parameters_MAG.json"

New-AzDeployment `
  -Name "AVD-Alerts-Solution" `
  -TemplateParameterFile $paramfile `
  -Location "usgovvirginia" `
  -TemplateFile $Deployment

$Deployment = "C:\GitRepo\AVDAlerts\modules\deploymentScript.bicep"
$paramFile = "C:\GitRepo\AVDAlerts\modules\deploymentScript.parameters.json"

New-AzResourceGroupDeployment `
    -Name "Test-Deployment-Script" `
    -ResourceGroupName rg-avdmetrics-d-eastus2 `
    -TemplateParameterFile $paramFile `
    -TemplateFile $Deployment


