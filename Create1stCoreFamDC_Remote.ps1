# Variables 
Param(
    [Parameter(Mandatory=$true,
    ParameterSetName="DomainNameFQDN")]
    [string[]]
    $domainname,

    [Parameter(Mandatory=$true,
    ParameterSetName="SafeModePassword")]
    [string[]]
    $SafeModePassword,
)


#  Configure Data Disk
Initialize-Disk 2 -Confirm:$false
new-partition -disknumber 2 -usemaximumsize -DriveLetter S | format-volume -filesystem NTFS -newfilesystemlabel SYSVOL -Force -Confirm:$false

#Install AD DS, DNS and GPMC
$featureLogPath = "c:\featurelog.txt"
start-job -Name addFeature -ScriptBlock {
Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools }
Wait-Job -Name addFeature
Get-WindowsFeature | Where installed >>$featureLogPath

# Create New Forest, add Domain Controller
#$SafeModePassword = ConvertTo-SecureString "P@ssw0rd12345" -AsPlainText -Force
#$domainname = "lab.corefamily.net"
$netbiosName = $domainname.split(".")[0]
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false `
-DatabasePath "S:\Windows\NTDS" `
-DomainMode 7 `
-DomainName $domainname `
-DomainNetbiosName $netbiosName `
-ForestMode 7 `
-InstallDns:$true `
-LogPath "S:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "S:\Windows\SYSVOL" `
-SafeModeAdministratorPassword $SafeModePassword `
-Force:$true