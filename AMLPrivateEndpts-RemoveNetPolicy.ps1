<#
Script based on documentation below:

https://docs.microsoft.com/en-us/azure/private-link/disable-private-endpoint-network-policy

Connect to Azure and prompting for subscription to set context to
Prompting and menus to gather the noted variables in document
Show Subnet settings and Set if desired
#>


Connect-AzAccount

$Subs = Get-AzSubscription
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }

$Selection = Read-Host "Subscription"
$Selection = $Subs[$Selection-1]
Select-AzSubscription -SubscriptionObject $Selection | Out-Null 

CLS
$VNets = Get-AzVirtualNetwork
Foreach($VNet in $VNets){
    Write-Host ($VNets.Indexof($Vnet)+1) "-" $Vnet.Name " : " $VNet.AddressSpace.AddressPrefixes
 }

$Selection = Read-Host "Select number corresponding to the VNet"
$VNet = $VNets[$Selection-1]

CLS
$Subnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet
Write-Host "0 - Exit"
Foreach($Subnet in $Subnets){
    Write-Host ($Subnets.Indexof($Subnet)+1) "-" $Subnet.Name " : " $Subnet.PrivateEndpointNetworkPolicies
 }
$Selection = Read-Host "To CHANGE the PrivateEndpointNetworkPolicies select the appropriate subnet or 0 <zero> to EXIT"
If($Selection -eq 0){Break} 

$SubnetToChange = $Subnets[$Selection-1]
$SubnetName = $SubnetToChange.Name

Write-Host ""
If($SubnetToChange.PrivateEndpointNetworkPolicies -eq 'Enabled'){$SetPolicyTo = "Disabled"}
If($SubnetToChange.PrivateEndpointNetworkPolicies -eq 'Disabled'){$SetPolicyTo = "Enabled"}

($VNet | Select -ExpandProperty subnets | Where-Object  {$_.Name -eq $SubnetName}).PrivateEndpointNetworkPolicies = $SetPolicyTo
Write-Host "Changing" $SubnetName "to" $SetPolicyTo "..." -ForegroundColor Yellow
$VNet | Set-AzVirtualNetwork | Out-Null

$SubnetNow = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet | Where Name -EQ $SubnetName
Write-Host $SubnetNow.Name " : " $SubnetNow.PrivateEndpointNetworkPolicies -ForegroundColor Green



