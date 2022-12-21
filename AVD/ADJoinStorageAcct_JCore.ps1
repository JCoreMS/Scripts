##  UPDATED VERSION by JCore
##   Downloads and extracts needed module and prompts for needed information. No cut and paste needed!

## PRE_REQS
#  RSAT for Active Directory
#  Run from AD Domain Joined VM
#  - Need Line of site to Domain Controller to run script for domain join 
#  

Install-Module az -Verbose -AllowClobber -Confirm:$true
Import-module -Name ActiveDirectory

# Download they needed Module per the documentation
Write-Host "Downloading AzFilesHybrid module..."
Invoke-WebRequest -Uri https://github.com/Azure-Samples/azure-files-samples/releases/download/v0.2.4/AzFilesHybrid.zip -OutFile .\AzFilesHybrid.zip
Write-Host "Unzipping downloaded AzFilesHybrid modules..."
Expand-Archive -Path .\AzFilesHybrid.zip -DestinationPath .\AzFilesHybrid -Verbose -Force

# Change the execution policy to unblock importing AzFilesHybrid.psm1 module
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# Navigate to where AzFilesHybrid is unzipped and stored and run to copy the files into your path
cd .\AzFilesHybrid
.\CopyToPSPath.ps1


# Import AzFilesHybrid module
Import-Module -Name AzFilesHybrid

# Login with an Azure AD credential that has either storage account owner or contributer Azure role assignment
# If you are logging into an Azure environment other than Public (ex. AzureUSGovernment) you will need to specify that.
# See https://docs.microsoft.com/azure/azure-government/documentation-government-get-started-connect-with-ps
# for more information.
Connect-AzAccount

# Get Subscription based on list
Write-Host "Getting Azure Subscription(s)" -ForegroundColor Yellow
$Subs = Get-AzSubscription
If(($Subs).count -gt 1){    # More than one sub, prompt
    $num = 0
    Write-Host "---> Which Subscription is the Storage Account in? (Select a Number)" -ForegroundColor Yellow
    Foreach ($Sub in $Subs) { $num++; Write-Host $num":" $Sub.Name}
    Write-Host ""
    $selection = Read-Host -Prompt "Select Subscription"
    $Subscription = $Subs.Item($Selection-1)
    Write-Host "Setting Subscription to selected" -ForegroundColor Yellow
    Select-AzSubscription -Subscription $Subscription.Name
}
Else{$Subscription = $Subs ;Write-Host "---> Only 1 subscription found, using that one: "$Subscription.Name}


# Get Storage Account(s) and Resource Group it's in
Write-Host "Getting Azure Resource Group(s)" -ForegroundColor Yellow
$StoreAccts = Get-AzStorageAccount
If(($StoreAccts).count -gt 1){    # More than one RG, prompt
    $num = 0
    Write-Host "---> Which Storage Account do you want to join to the domain? (Select a Number)" -ForegroundColor Yellow
    Foreach ($StoreAcct in $StoreAccts) { $num++; Write-Host $num":" $StoreAcct.StorageAccountName}
    Write-Host ""
    $selection = Read-Host -Prompt "Select Resource Group"
    $StoreAcct = $StoreAccts.Item($Selection-1)
}
Else{$StoreAcct = $StoreAccts}

# Determine if specific OU is desired in AD
$SpecifyOU = Read-Host "Do you want to specify the OU to place the computer object in? (Y or N)"
$SpecifyOU = $SpecifyOU.ToUpper()


# Define parameters, $StorageAccountName currently has a maximum limit of 15 characters
$ResourceGroupName = $StoreAcct.ResourceGroupName
$StorageAccountName = $StoreAcct.StorageAccountName

# If you don't provide the OU name as an input parameter, the AD identity that represents the storage account is created under the root directory.
If($SpecifyOU -eq 'Y'){
    $OuDistinguishedName = Read-Host "Input the exact Distinguised Name of the OU you'd like the machine account created in. (no quotes)"
    }
Else{$OuDistinguishedName = $false}

# AD Computer Account Name.
$SamAccountName = Read-Host "Input AD Computer Account Name to use"

# Specify the encryption agorithm used for Kerberos authentication. Default is configured as "'RC4','AES256'" which supports both 'RC4' and 'AES256' encryption.
$EncryptionType = "AES256"

# Register the target storage account with your active directory environment under the target OU (for example: specify the OU with Name as "UserAccounts" or DistinguishedName as "OU=UserAccounts,DC=CONTOSO,DC=COM"). 
# You can use to this PowerShell cmdlet: Get-ADOrganizationalUnit to find the Name and DistinguishedName of your target OU. If you are using the OU Name, specify it with -OrganizationalUnitName as shown below. If you are using the OU DistinguishedName, you can set it with -OrganizationalUnitDistinguishedName. You can choose to provide one of the two names to specify the target OU.
# You can choose to create the identity that represents the storage account as either a Service Logon Account or Computer Account (default parameter value), depends on the AD permission you have and preference. 
# Run Get-Help Join-AzStorageAccountForAuth for more details on this cmdlet.
Write-Host "Adding Storage Account to domain...." -foregroundcolor yellow
If($OuDistinguishedName -eq $false){
Join-AzStorageAccountForAuth `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -SamAccountName $SamAccountName `
        -DomainAccountType 'ComputerAccount' `
        -EncryptionType $EncryptionType
}


Else{
Join-AzStorageAccountForAuth `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -SamAccountName $SamAccountName `
        -DomainAccountType 'ComputerAccount' `
        -OrganizationalUnitDistinguishedName $OuDistinguishedName `
        -EncryptionType $EncryptionType
}

Write-Host "Setting for AES 256 Encryption" -ForegroundColor Yellow
#Run the command below if you want to enable AES 256 authentication. If you plan to use RC4, you can skip this step.
Update-AzStorageAccountAuthForAES256 -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName
Write-Host "Testing connection..." -ForegroundColor Yellow
#You can run the Debug-AzStorageAccountAuth cmdlet to conduct a set of basic checks on your AD configuration with the logged on AD user. This cmdlet is supported on AzFilesHybrid v0.1.2+ version. For more details on the checks performed in this cmdlet, see Azure Files Windows troubleshooting guide.
Debug-AzStorageAccountAuth -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName -Verbose
