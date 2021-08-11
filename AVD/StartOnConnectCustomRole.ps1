

$RoleDef = 
@"
{
    "Name": "Start VM OnConnect (Custom)",
    "description": "Start VM on Connect configured to allow users access to start AVD VMs with host pool setting enabled.",
    "IsCustom": true,
    "actions": [
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/read"
    ],
    "notActions": [],
    "dataActions": [],
    "notDataActions": [],
    "assignableScopes": [
        "/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9"
    ]
}
"@
### Save the command to a local file
Set-Content -Path .\AVDStartConnectCustomRole.json -Value $RoleDef
New-AzRoleDefinition -InputFile .\AVDStartConnectCustomRole.json
Remove-Item -Path .\AVDStartConnectCustomRole.json -Force