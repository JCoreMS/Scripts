###############################################################################################################
#
#  Configures AVD in Azure Commercial to use VMs in Azure Government!
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
#   Update 3/15/2022 - (feature) added prompting to select resource items needed versus manually adding to script - JCore
#
###############################################################################################################


###################################################################
# Connect and select Azure Sub, RG and Host Pools for each Cloud
###################################################################
Clear-Host
$Clouds = @("AzureUsGovernment", "AzureCloud")
Write-host "Connect and Authenticate to each cloud..."
Foreach($cloud in $Clouds) {
    Clear-Host
    Write-host "Connect and Authenticate to $cloud. (Look for minimized Window!)" -ForegroundColor Cyan
    Connect-AzAccount -Environment $cloud
    Write-Host "Getting List of Subscriptions..." -ForegroundColor Cyan
    $Subs = Get-AzSubscription | Sort-Object -Property Name
    If ($Subs.count -ne 1){
        $i = 1
        Foreach($Sub in $Subs){
            Write-Host $i "-" $Sub.Name
            $i ++
        }
        $Environment = Read-Host "Select $cloud Subscription"
        $Environment = $Subs[$Environment-1]
    } 
    Else {
        Write-Host "Only one Subscription found: " $Subs -ForegroundColor Yellow
        $Environment = $Subs
    }
    
    
    If($cloud -eq "AzureUsGovernment"){$Sub = Select-AzSubscription -SubscriptionObject $Environment}
    else {$Sub = Select-AzSubscription -Subscription $Environment}

    # Resource Groups
    Clear-Host
    Write-Host "Getting List of Resource Groups..." -ForegroundColor Cyan
    $RGs = Get-AzResourceGroup -DefaultProfile $Sub | Sort-Object -Property ResourceGroupName
    If ($RGs.count -ne 1){
        $i = 1
        Foreach($RG in $RGs){
            Write-Host $i "-" $RG.resourcegroupname
            $i ++
        }
        $ResourceGroup = Read-Host "Select $cloud Resource Group with Host Pool resources"
        $ResourceGroup = $RGs[$ResourceGroup-1]
    }
    Else {
        Write-Host "Only one Resource Group found: " $RGs -ForegroundColor Yellow
        $ResourceGroup = $RGs
    }

    # Host Pools
    Clear-Host
    Write-Host "Getting List of Host Pools..." -ForegroundColor Cyan
    $HPs = Get-AzWvdHostPool -DefaultProfile $Sub | Sort-Object -Property Name
    If ($HPs.count -ne 1){
        $i = 1
        Foreach($HP in $HPs){
            Write-Host $i "-" $HP.Name
            $i ++
        }
        $HostPool = Read-Host "Select $cloud Host Pool"
        $HostPool = $HPs[$HostPool-1]
    }
    Else {
        Write-Host "Only one Host Pool found: " $HPs -ForegroundColor Yellow
        $HostPool = $HPs
    }

    If($cloud -eq "AzureUsGovernment"){
        $GovResourceGroup = $ResourceGroup
        $GovHostPool = $HostPool
        $GovSubscription = $Sub
        $GovSubscriptionID = $Sub.Subscription.Id
    }
    else {
        $CommResourceGroup = $ResourceGroup
        $CommHostPool = $HostPool
        $CommSubscription = $Sub
        $CommSubscriptionID = $Sub.Subscription.Id
    }


} # End Foreach Cloud
###################################################################
# Summary - Verify Selections
###################################################################
Clear-Host
Write-Host "                          SUMMARY:" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------"
Write-Host "                        US Government"
Write-Host "--------------------------------------------------------------------------"
Write-Host "Subscription:   " $GovSubscription.Subscription.Name
Write-Host "Resource Group: " $GovResourceGroup.ResourceGroupName
Write-Host "Host Pool:      " $GovHostPool.Name
Write-Host "--------------------------------------------------------------------------"
Write-Host "                         Commercial"
Write-Host "--------------------------------------------------------------------------"
Write-Host "Subscription:   " $CommSubscription.Subscription.Name
Write-Host "Resource Group: " $CommResourceGroup.ResourceGroupName
Write-Host "Host Pool:      " $HostPool.Name
Write-Host ""
$Go = Read-Host "Hit Y to continue"
If ($Go.ToUpper() -ne 'Y'){Break}

Clear-Host
#################################
#Step 0 - Install WVD Module... in case you don't have it
#################################
# Install-Module -Name Az.DesktopVirtualization

#################################
#Step 1 - Connect to Azure Commercial and retrieve Commercial Host Pool Token
#################################
Write-Host "Getting Commercial Host Pool Regisration Token..." -ForegroundColor Green
$CommPool = Get-AzWvdRegistrationInfo -ResourceGroupName $CommResourceGroup -HostPoolName $CommHostPool
$Token = $CommPool.Token

#################################
#Step 2 - Build Command to run in VMs
#################################
Write-Host "Setting Temporary PowerShell Script 'RegNewPool.PS1' and saving locally..." -ForegroundColor Green
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
Write-Host "Getting VMs from Government Host Pool.." -ForegroundColor Green
Select-AzSubscription -SubscriptionId $GovSubscriptionID
$VMs = Get-AZWVDSessionHost -ResourceGroupName $GovResourceGroup -HostPoolName $GovHostPool 
Foreach ($VM in $VMs) { 

	$DNSname = $VM.name.split("/")[1]
	$VMname = $DNSname.split(".")[0]
	#################################
	#remove host from Gov Pool
	#################################
    Write-Host "Removing VMs from Government Host Pool..." -ForegroundColor Green
	Remove-AZWVDSessionHost -ResourceGroupName $GovResourceGroup -HostPoolName $GovHostPool -SessionHostName $DNSname

	#################################
	# call PowerShell inside VM to register with Commercial Pool
	#################################
    Write-Host "Running PowerShell script against VMs to register in Commercial Host Pool..." -ForegroundColor Green
	Invoke-AzVMRunCommand -Name $VMname -ResourceGroupName $GovResourceGroup -CommandId 'RunPowerShellScript' -ScriptPath .\RegNewPool.PS1
}
#################################
### Clean-up the local file
#################################
Write-Host "Removing Temporary PowerShell Script saved Locally..." -ForegroundColor Green
Remove-Item .\RegNewPool.PS1

Write-Host "FINISHED!"