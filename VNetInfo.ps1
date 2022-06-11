
$subscriptions = get-azsubscription
$outfile = "C:\temp\temp.csv"

"Subscription,VNet Name,IP Space" | Out-File $outfile -Encoding ascii

Foreach($subscription in $subscriptions){
    Set-AzContext -Subscription $subscription.ID | Out-Null
    Write-Host "Working on: " $subscription.Name
    $Vnets = Get-AzVirtualNetwork
    
    Foreach($Vnet in $Vnets){
        Write-Host "...." $VNet.Name
        $Subscription.Name+','+$VNet.Name+ ','+$VNet.AddressSpace.AddressPrefixes | Out-File $outfile -Append       


    }


}