# Connect-AzAccount -Environment AzureUSGovernment
#Remove-AzResourceGroup -Name rg-eastus2-p-AVDAlerts -Force


$LogFile = ".\AzureRemoveStaleIdenties_RG.log"
$ReportOnly = $false

function write-log
{
Param ([string]$logstring)

Add-content $Logfile -Value $logstring
}

If($ReportOnly){write-log "REPORTING ONLY - No Actions taken`n"}
If(!$ReportOnly){write-log "LIST OF STALE ROLES REMOVED`n"}
$Runtime = Get-Date
write-log "----------------------- Runtime: $Runtime -----------------------`n"

# Clean up current subscription
# $RBACSub = Get-AzRoleAssignment -ResourceName 


$resourceGroups = Get-AzResourceGroup
Foreach($resourceGroup in $resourceGroups){
    Write-Host "Working on Resource Group: " $resourceGroup.ResourceGroupName -ForegroundColor Cyan
    $RGId = $resourceGroup.ResourceId
    $RBAC = Get-AzRoleAssignment -ResourceGroupName $resourceGroup.ResourceGroupName | Where-Object {$_.DisplayName -eq $null -and $_.Scope -eq $RGId}
    If($RBAC.count -gt 0){
        Foreach($role in $RBAC){
            Write-Host "Found 'Identity Not Found' for" $role.RoleDefinitionName -ForegroundColor Yellow
            If($ReportOnly){
                Write-Host "----> Logging Only!" -ForegroundColor Yellow}
            If(!$ReportOnly){
                Write-Host "----> Logging and Removing!" -ForegroundColor Red
                Remove-AzRoleAssignment -InputObject $role
            }
            write-log ($role | ConvertTo-Json)
            write-log "----------------------------------------------------"

        } #end foreach
     } # end if           
}