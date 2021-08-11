
#Connect-AzAccount
#Get-AzSubscription
#Select-AzSubscription -Subscription "Microsoft Azure Internal Consumption"


$VMName = "CoreFamDC01"
$VM = Get-azVM -Name $VMName

Invoke-AzVMRunCommand -Name $VMname -ResourceGroupName $VM.ResourceGroupName -CommandId 'RunPowerShellScript' -ScriptPath .\Create1stCoreFamDC.PS1