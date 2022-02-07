###############################################################################################################
#
#  Configures WVD in Azure Commercial to use VMs in Azure Government!
#
# Assumes: 
#	pool created in Azure Commercial (with no VMs in it!),
#	pool created in Azure Gov WITH VMs, that will be registered in the Commercial pool
#	(VMs in Gov pool will be poached and registered in Commercial...just using Gov Pool to provision!)
# 
#  questions - johnkel at Microsoft.com
#
#  Version History:
#	Update 9/29/2020 - (bugs) fixed a few variables that had been adjusted 
#
###############################################################################################################
#
#################################
# Azure Settings & other parms
#################################
$GovResourceGroup 	= "GBBComm"
$GovSubscriptionID	= "11111111-1111-1111-1111-111111111111"
$GovHostPool		= "VMsforCommercial"	

$CommResourceGroup 	= "CommercialWVD"
$CommSubscriptionID	= "22222222-2222-2222-2222-222222222222"
$CommHostPool		= "GovVMs"	

#################################
#Step 0 - Install WVD Module... in case you don't have it
#################################
# Install-Module -Name Az.DesktopVirtualization

#################################
#Step 1 - Connect to Azure Commercial and retrieve Commercial Host Pool Token
#################################
Connect-AzAccount 
Select-AzSubscription -SubscriptionId $CommSubscriptionID
$CommPool = Get-AzWvdRegistrationInfo -ResourceGroupName $CommResourceGroup -HostPoolName $CommHostPool
$Token = $CommPool.Token

#################################
#Step 2 - Build Command to run in VMs
#################################
$remoteCommand =
@"
#### Run Unregister from Gov Pool / Reregister with Commercial Pool
Stop-Service RDAgentBootLoader
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' IsRegistered -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' RegistrationToken -Value $Token
Start-Service RDAgentBootLoader
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent'
"@
### Save the command to a local file
Set-Content -Path .\RegNewPool.PS1 -Value $remoteCommand

#################################
#Step 3 - Remove VMs from Gov Pool & register with Commercial Pool
#################################
Connect-AzAccount -EnvironmentName AzureUSGovernment 
Select-AzSubscription -SubscriptionId $GovSubscriptionID
$VMs = Get-AZWVDSessionHost -ResourceGroupName $GovResourceGroup -HostPoolName $GovHostPool 
Foreach ($VM in $VMs) { 

	$DNSname = $VM.name.split("/")[1]
	$VMname = $DNSname.split(".")[0]
	#################################
	#remove host from Gov Pool
	#################################
	Remove-AZWVDSessionHost -ResourceGroupName $GovResourceGroup -HostPoolName $GovHostPool -SessionHostName $DNSname

	#################################
	# call PowerShell inside VM to register with Commercial Pool
	#################################
	Invoke-AzVMRunCommand -Name $VMname -ResourceGroupName $GovResourceGroup -CommandId 'RunPowerShellScript' -ScriptPath .\RegNewPool.PS1
}
#################################
### Clean-up the local file
#################################
Remove-Item .\RegNewPool.PS1


1. Remove from Gov Host Pool
2. Get token from commercial host pool
2. Run script against VM in portal to register in commercial 