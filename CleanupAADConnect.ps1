# Import Module
Install-Module -Name MSOnline -AllowClobber -Force

#specify credentials for azure ad connect
$Msolcred = Get-credential
#connect to azure ad
Connect-MsolService -Credential $MsolCred -AzureEnvironment AzureUSGovernmentCloud

#disable AD Connect / Dir Sync
Set-MsolDirSyncEnabled -EnableDirSync $false

#confirm AD Connect / Dir Sync disabled
(Get-MSOLCompanyInformation).DirectorySynchronizationEnabled