###############################################################################################################
#
#  Configures AVD for cross cloud by registering the AVD VMs in an existing Host Pool in a Source Cloud to
#  another existing Host Pool in a Target Cloud.  (i.e. VMs need to be in US Gov Cloud but user accounts are in Azure Global)
#
# Assumes: 
#	pool created in Target Cloud (with no VMs in it!),
#	pool created in Source Cloud WITH VMs, that will be registered in the Target pool
#	(VMs in Source pool will be unregistered and re-registered in the Target pool...just using Source Pool to provision!)
# 
#  questions - johnkel at Microsoft.com
#
#  Version History:
#	Update 9/29/2020 - (bugs) fixed a few variables that had been adjusted
#   Update 3/15/2022 - (feature) added prompting to select resource items needed versus manually adding to script - JCore
#   Update 10/10/2022 - (feature) revised prompting and use of functions to specify source and target
#
###############################################################################################################
Clear-Host
Write-Host "This script will unregister AVD VMs in an existing Host Pool and re-register them in an Empty Host Pool in another Azure Cloud." -ForegroundColor Cyan
Write-Host "Pre-requisites:" -ForegroundColor Yellow
Write-Host "  1. Existing Subscription and AVD Host Pool in both Source and Target Cloud Environments"
Write-Host "  2. Azure Cloud account on both Cloud Environments"
Write-Host "  3. Virtual Desktop Contributor Role on both Cloud Environments"
Write-Host "  4. Azure Powershell Modules for Az.Accounts, Az.DesktopVirtualization, and Az.Resources installed"
Write-Host ""
Pause

Clear-Host
$CloudList = (Get-AzEnvironment).Name
$i = 1
Foreach ($item in $CloudList) {
    $item = $item.Replace('Azure','')
    $item = $Item.Replace('Cloud','')
    if($item -eq ''){$item = 'Commercial / Global'}
    Write-Host $i "-" $item
    $i ++
}
$SourceSelect = Read-Host "Select Source Cloud Environment where AVD Hosts are currently registered."
$SourceCloud = $CloudList[$SourceSelect - 1]
$SourceSelect = Read-Host "Select Target Cloud Environment where you would like to re-register AVD VMs in."
$TargetCloud = $CloudList[$SourceSelect -1]

#################################
#Step 0 - Install WVD Module... in case you don't have it
#################################
# Install-Module -Name Az.DesktopVirtualization -Verbose -Force

###################################################################
# Connect and select Azure Sub, RG and Host Pools Function
###################################################################
Function Get-AVDHostPoolInfo ($cloud) {
    Clear-Host
    Write-host "Connect and Authenticate to $cloud. (Look for minimized Window!)" -ForegroundColor Cyan
    Connect-AzAccount -Environment $cloud
    Write-Host "Getting List of Subscriptions..." -ForegroundColor Cyan
    $Subs = Get-AzSubscription | Sort-Object -Property Name
    If ($Subs.count -ne 1) {
        $i = 1
        Foreach ($Sub in $Subs) {
            Write-Host $i "-" $Sub.Name
            $i ++
        }
        $Environment = Read-Host "Select $cloud Subscription"
        $Environment = $Subs[$Environment - 1]
    } 
    Else {
        Write-Host "Only one Subscription found: " $Subs -ForegroundColor Yellow
        $Environment = $Subs
    }

    # Resource Groups
    Clear-Host
    Write-Host "Getting List of Resource Groups..." -ForegroundColor Cyan
    Set-AzContext -SubscriptionObject $Environment | Out-Null
    $RGs = Get-AzResourceGroup | Sort-Object -Property ResourceGroupName
    If ($RGs.count -ne 1) {
        $i = 1
        Foreach ($RG in $RGs) {
            Write-Host $i "-" $RG.resourcegroupname
            $i ++
        }
        $ResourceGroup = Read-Host "Select $cloud Resource Group with Host Pool resources"
        $ResourceGroup = $RGs[$ResourceGroup - 1]
    }
    Else {
        Write-Host "Only one Resource Group found: " $RGs -ForegroundColor Yellow
        $ResourceGroup = $RGs
    }

    # Host Pools
    Clear-Host
    Write-Host "Getting List of Host Pools..." -ForegroundColor Cyan
    $HPs = Get-AzWvdHostPool -DefaultProfile $Sub | Sort-Object -Property Name
    If ($HPs.count -ne 1) {
        $i = 1
        Foreach ($HP in $HPs) {
            Write-Host $i "-" $HP.Name
            $i ++
        }
        $HostPool = Read-Host "Select $cloud Host Pool"
        $HostPool = $HPs[$HostPool - 1]
    }
    Else {
        Write-Host "Only one Host Pool found: " $HPs -ForegroundColor Yellow
        $HostPool = $HPs
    }

    $AVDInfo = [PSCustomObject]@{
        SubName = $Environment.Name
        SubId = $Environment.Id
        ResourceGroup = $ResourceGroup.ResourceGroupName
        HostPool = $HostPool.Name
    }
    
    Return $AVDInfo

}

#################################
#Step 1 - Connect to Target Environment and acquire Host Pool Token
#################################
$HostPoolTargetInfo = Get-AVDHostPoolInfo -cloud $TargetCloud
Write-Host "Getting Commercial Host Pool Registration Token..." -ForegroundColor Green
$TargetPool = Get-AzWvdRegistrationInfo -ResourceGroupName $HostPoolTargetInfo.ResourceGroup -HostPoolName $HostPoolTargetInfo.HostPool
If ($TargetPool.Token -eq $null){
    Write-Host "Not Host Pool Registration Token found, creating one..."
    $RegistrationInfo = New-AzWvdRegistrationInfo -ResourceGroupName $HostPoolTargetInfo.ResourceGroup -HostPoolName $HostPoolTargetInfo.HostPool -ExpirationTime (Get-Date).AddDays(1)
    $Token = $RegistrationInfo.Token
}
else {$Token = $TargetPool.Token}


#################################
#Step 2 - Build Command to run in VMs
#################################
Write-Host "Setting Temporary PowerShell Script 'RegNewPool.PS1' and saving locally..." -ForegroundColor Green
$remoteCommand =
@"
#### Run Unregister from $SourceCloud Pool / Reregister with $TargetCloud Pool
Stop-Service RDAgentBootLoader
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' IsRegistered -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' RegistrationToken -Value $Token
Start-Service RDAgentBootLoader
# Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent'
"@
### Save the command to a local file
Set-Content -Path .\RegNewPool.PS1 -Value $remoteCommand

#################################
#Step 3 - Remove VMs from Source Pool & register with Target Pool
#################################
$HostPoolSourceInfo = Get-AVDHostPoolInfo -cloud $SourceCloud
Write-Host "Getting VMs from Target Host Pool.." -ForegroundColor Green
$VMs = Get-AZWVDSessionHost -ResourceGroupName $HostPoolSourceInfo.ResourceGroup -HostPoolName $HostPoolSourceInfo.HostPool

Foreach ($VM in $VMs) { 

    $DNSname = $VM.name.split("/")[1]
    $VMname = $DNSname.split(".")[0]
    #################################
    #remove host from Source Pool
    #################################
    Write-Host "Removing VM $VMname from $SourceCloud Host Pool..." -ForegroundColor Green
    Remove-AZWVDSessionHost -ResourceGroupName $HostPoolSourceInfo.ResourceGroup -HostPoolName $HostPoolSourceInfo.HostPool -SessionHostName $DNSname

    #################################
    # call PowerShell inside VM to register with Target Pool
    #################################
    Write-Host "Running PowerShell script against VM $VMname to register in $TargetCloud Host Pool..." -ForegroundColor Green
    Invoke-AzVMRunCommand -Name $VMname -ResourceGroupName $HostPoolSourceInfo.ResourceGroup -CommandId 'RunPowerShellScript' -ScriptPath .\RegNewPool.PS1
}
#################################
### Clean-up the local file
#################################
Write-Host "Removing Temporary PowerShell Script saved Locally..." -ForegroundColor Green
Remove-Item .\RegNewPool.PS1

###################################################################
# Summary
###################################################################
Write-Host ""
Write-Host "              AVD Host Registration SUMMARY:" -ForegroundColor Green
Write-Host "--------------------------------------------------------------------------"
Write-Host "                           FROM: $SourceCloud" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------"
Write-Host "Subscription:   " $HostPoolSourceInfo.SubName
Write-Host "Resource Group: " $HostPoolSourceInfo.ResourceGroup
Write-Host "Host Pool:      " $HostPoolSourceInfo.HostPool
Write-Host "--------------------------------------------------------------------------"
Write-Host "                            TO: $TargetCloud" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------"
Write-Host "Subscription:   " $HostPoolTargetInfo.SubName
Write-Host "Resource Group: " $HostPoolTargetInfo.ResourceGroup
Write-Host "Host Pool:      " $HostPoolTargetInfo.HostPool
Write-Host ""




