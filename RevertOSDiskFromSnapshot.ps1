<#
Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts
are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, 
without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire
risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event
shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be
liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business
interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use
the sample scripts or documentation, even if Microsoft has been advised of the  possibility of such damages.



 This script is designed to restore a snapshot to a VM in Azure.
 The process involves the following steps:
  1. Login to Azure and enumerate the Subscriptions
  2. Enumerate the current VMs in the Subscription
  3. Enumerate the snapshots in the same Resource Group
  4. Swap OS Disk to the snapshot or your choosing (restart of VM required)
#>

#   GET SUBSCRIPTION / VM / DISK INFO
Write-Host "Connecting to Azure... (There may be a hidden window for logon)" -ForegroundColor Yellow
Connect-AzAccount
Write-Host "Getting Azure Subscription(s)" -ForegroundColor Yellow
$Subs = Get-AzSubscription
If(($Subs).count -gt 1){    # More than one sub, prompt
    $num = 0
    Write-Host "---> Which Subscription is the Virtual Machine in? (Select a Number)" -ForegroundColor Yellow
    Foreach ($Sub in $Subs) { $num++; Write-Host $num":" $Sub.Name}
    Write-Host ""
    $selection = Read-Host -Prompt "Select Subscription"
    $Subscription = $Subs.Item($Selection-1)
}
Else{$Subscription = $Subs}
Write-Host "Setting Subscription" -ForegroundColor Yellow
Select-AzSubscription -Subscription $Subscription.Name

#   GET AZURE VM 
Write-Host "Getting Azure VM(s)" -ForegroundColor Yellow
$VMs = Get-AzVM 
If(($VMs).count -gt 1){    # More than one sub, prompt
    $num = 0
    Write-Host "---> Which VM do you want to restore a snapshot in? (Select a Number)" -ForegroundColor Yellow
    Foreach ($VM in $VMs) { $num++; Write-Host $num":" $VM.Name}
    Write-Host ""
    $selection = Read-Host -Prompt "Select VM"
    $VM = $Vms.Item($Selection-1)
}
Else{$VM = $VMs}
Write-Host "Setting VM" -ForegroundColor Yellow
$OSDisk = ($VM.StorageProfile.OsDisk).Name
$VMName = $VM.Name
$ResourceGroupName = $VM.ResourceGroupName

#   GET AZURE SNAPSHOT(S)
Write-Host "Getting Azure VM(s)" -ForegroundColor Yellow
$SnapShots = Get-AzSnapshot
If($SnapShots -eq $Null){Write-Host "No Snapshots Found! Exiting"; Break}

If(($Snapshots).count -gt 1){    # More than one sub, prompt
    $num = 0
    Write-Host "---> Which snapshot would you like to restore from? (Select a Number)" -ForegroundColor Yellow
    Foreach ($SnapShot in $SnapShots) { $num++; Write-Host $num":" $SnapShot.Name}
    Write-Host ""
    $selection = Read-Host -Prompt "Select SnapShot"
    $SnapShot = $SnapShots.Item($Selection-1)
}
Else{$SnapShot = $Snapshots}
Write-Host "Setting SnapShot: " $Snapshot.Name -ForegroundColor Yellow

#   CONFIGURE VM WITH NEW DISK
Write-Host "Stopping VM" -ForegroundColor Yellow
Stop-azVM -ResourceGroupName $VM.ResourceGroupName -Name $VMName -Confirm:$false

Write-Host "Creating New Disk from Snapshot" -ForegroundColor Yellow
$OSDiskAppend = "FmSnapShotCreated_" + (($Snapshot.TimeCreated).ToString("s")).Replace(':','-')
$OSDiskNameComp = $OSDisk.Split('_')
$OSDiskRemoveComp = $OSDiskNameComp.Item($OSDiskNameComp.Length-1)
$NewOSDiskName = $OSDisk.Replace($OSDiskRemoveComp, $OSDiskAppend) 

Write-Host "---> New Disk Name: " $NewOSDiskName -ForegroundColor Yellow
$VMDiskInfo = $VM.StorageProfile.OsDisk.ManagedDisk

$newDiskConfig = New-AzDiskConfig -Location $VM.Location -CreateOption Copy -SourceResourceId $Snapshot.Id
$newdisk = New-AzDisk -DiskName $NewOSDiskName -Disk $newDiskConfig -ResourceGroupName $ResourceGroupName -Verbose

Write-Verbose "Stopping virtual machine" -ForegroundColor Yellow
Stop-AzVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -Verbose -Force

Write-Verbose "Updating OS disk" -ForegroundColor Yellow
Set-AzVMOSDisk -VM $VM -ManagedDiskId $newdisk.Id -Name $newdisk.Name -Verbose
Update-AzVM -VM $VM -ResourceGroupName $ResourceGroupName -Verbose

Write-Verbose "Starting virtual machine" -ForegroundColor Yellow
Start-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Verbose

Write-Host "COMPLETED" -ForegroundColor Green
Write-Host "New Disk Name: " $NewOSDiskName
Write-Host "Attached to: " $VMName
Get-AzVM -Name $VMName -Status

$DeletePrevious = Read-Host "Do you want to delete the previous Virtual Disk? (Y or N)"
If ($DeletePrevious.ToUpper() -eq 'Y'){
    Write-Host "---> Removing Previous disk: " $OSDisk -ForegroundColor Yellow
    Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $OSDisk -Force
}
Else{Write-Host "---> Previous Disk will NOT be deleted" -ForegroundColor Yellow}
Write-Host "COMPLETED" -ForegroundColor Green