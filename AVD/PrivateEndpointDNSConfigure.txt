
$PvtLinkZones = @('api.azureml.ms', 'instances.azureml.ms','notebooks.azure.net','aznbcontent.net')
$AzureDCs = @('azuredc01','azuredc02')
$AzureDCIPs = '10.10.10.5,10.10.10.6'
$OnPremDCs = @('hqdc01','hqdc02','BranchDC01')


Foreach ($AzureDC in $AzureDCs){
    # Process each Azure based DC
    Foreach($PvtLinkZone in $PvtLinkZones){
        Add-DnsServerConditionalForwarderZone -ComputerName $AzureDC -Name $PvtLinkZone -MasterServers 168.63.129.16 -PassThru
        }
}

Foreach ($OnPremDC in $OnPremDCs){
    # Process each OnPrem based DC
    Foreach($PvtLinkZone in $PvtLinkZones){
        Add-DnsServerConditionalForwarderZone -ComputerName $OnPremDC -Name $PvtLinkZone -MasterServers $AzureDCIPs -PassThru
        }
}