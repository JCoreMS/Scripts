Connect-AzAccount 
$Subscriptions = Get-AzSubscription
$i = 0
Write-Host 
Foreach ($Sub in $Subscriptions){$i++;Write-Host $i ": " $Sub.Name}
$Response = Read-Host "Which Subscription?"
$Subscription = $Subscriptions[$Response-1]
<#
Name                                  Id                                   TenantId                             State  
----                                  --                                   --------                             -----  
MSDN Internal                         9e6a528e-b016-4ade-b2c3-32451a1bda71 e5df932b-82ca-4872-a0bb-f880a766a051 Enabled
Visual Studio Enterprise Subscription d21af581-3282-4f7d-ba7f-c1e021c29ff0 e5df932b-82ca-4872-a0bb-f880a766a051 Enabled
FTA JCore - Azure CXP Internal        8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9 e5df932b-82ca-4872-a0bb-f880a766a051 Enabled
#>





$vms = Get-AzVM

foreach ($vm in $vms) {
    $agent = $vm | Select -ExpandProperty OSProfile | Select -ExpandProperty Windowsconfiguration | Select ProvisionVMAgent
    Write-Host $vm.Name $agent.ProvisionVMAgent
}



$vm = Get-AzVM -Name MSCorpVM1
$agent = $vm | Select -ExpandProperty OSProfile | Select -ExpandProperty Windowsconfiguration | Select ProvisionVMAgent

$vm.OSProfile.AllowExtensionOperations = $True
$vm | Update-AzVM
