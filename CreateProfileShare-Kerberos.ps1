
<#
Create a profile container with Azure Files and Azure Active Directory (preview)

CODE COMPILED FROM: https://docs.microsoft.com/en-gb/azure/virtual-desktop/create-profile-container-azure-ad
4/1/2022

NOTE: "Set the password for the storage account's service principal" MUST be done/reset every 6 months!

POST SCRIPT CONFIG:
Set the API permissions on the newly created application.
Configure Azure Files
- Assign share-level permissions
- Assign Directory Level permissions (NTFS)
#>

# Azure Information / Variables Required
#$tenantId = "<MyTenantId>"
#$subscriptionId = "<MySubscriptionId>"
#$resourceGroupName = "<MyResourceGroup>"
#$storageAccountName = "<MyStorageAccount>"
#$Environment = "AzureCloud"


$storageAccountName = Read-Host "Input an existing Storage Account Name"
$fileShareName = Read-Host "Input the name of the Azure File Share (will be created if doesn't exist)"
$SMBelevated = Read-Host "Input an existing Group Name for SMB Elevated Contributors (Admins)" 
$SMBcontrib = Read-Host "Input an existing Group Name for your AVD users"

# Pre-reqs / Modules required
$Module = Get-Module ActiveDirectory;
 if ($null -eq $Module) {
    Write-Host "Installing ActiveDirectory Module..." -ForegroundColor Yellow
    Install-Module -Name ActiveDirectory -Verbose
}
$Module = Get-Module Az.Storage;
 if ($null -eq $Module) {
    Write-Host "Installing Az.Storage Module..." -ForegroundColor Yellow
    Install-Module -Name Az.Storage -Verbose
}
$Module = Get-Module AzureAD;
 if ($null -eq $Module) {
    Write-Host "Installing AzureAD Module..." -ForegroundColor Yellow
    Install-Module -Name AzureAD -Verbose
}

# Select Cloud if NOT Azure Commercial 
$Cloud = Read-Host "Connect to a Soveriegn Cloud?"
If($Cloud.ToUpper() -eq 'Y'){
    $CloudEnv = Get-AzureEnvironment
    $i = 1
    foreach ($env in $CloudEnv){
        Write-Host $i ":" $env.name
        $i ++ 
    }
    $Selection = Read-Host "Which Cloud Environment? (Choose Number)"
    $Environment = $CloudEnv[$Selection-1].Name
}
Else {$Environment = "AzureCloud"}

# Connect to Azure
$Credential = Get-Credential
Connect-AzAccount -Environment $Environment -Credential $Credential

# Get Subscription and select
$Subs = Get-AzSubscription
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }
$Selection = Read-Host "Subscription"
$Selection = $Subs[$Selection-1]
$SubscriptionId = (Select-AzSubscription -SubscriptionObject $Selection).Subscription.Id
$TenantId = (Select-AzSubscription -SubscriptionObject $Selection).Tenant.Id
$resourceGroupName = (Get-AzResource -ResourceName $storageAccountName).ResourceGroupName

# CHECKS - Storage account and Groups exist / file share create if not exist
Write-Host "Checking for storage account and connecting"
$storAcct = Get-AzResource -Name $storageAccountName  # null if does not exist
If($storAcct -eq ""){Write-Error "Storage Account does NOT exist!"; Break} 
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storageAccountName | select -first 1).Value
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

Write-Host "Checking for Azure File Share"
$azFileShare = Get-AzStorageShare -Name $fileShareName -Context $storageContext -ErrorAction SilentlyContinue
If($azFileShare -eq $null) {
    Write-Host "File Share does not exist - CREATING" -ForegroundColor Yellow
    $azFileShare = New-AzStorageShare -Name $fileShareName -Context $storageContext
}

# Configure Share Level Permissions on Azure Files Share Resource
$SMBcontrib = "azAVDUsers_MAC"
$SMBcontribID = (Get-azADGroup -DisplayName $SMBcontrib).id
New-AzRoleAssignment -ObjectId $SMBcontribID -RoleDefinitionName "Storage File Data SMB Share Contributor" `
    -ResourceName $fileShareName `
    -ResourceType "Microsoft.Storage/storageAccounts/fileServices/fileshares/files" `
    -ResourceGroupName $resourceGroupName

# **********************************************************************************************************  WORKING

# Enable Azure AD authentication on your storage account
$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $subscriptionId, $resourceGroupName, $storageAccountName);

$json = @{properties=@{azureFilesIdentityBasedAuthentication=@{directoryServiceOptions="AADKERB"}}};
$json = $json | ConvertTo-Json -Depth 99

$token = $(Get-AzAccessToken).Token
$headers = @{ Authorization="Bearer $token" }

try {
    Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
} catch {
    Write-Host $_.Exception.ToString()
    Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
}

# Generate the kerb1 storage account key for your storage account
New-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName -KeyName kerb1 -ErrorAction Stop

#------------------------------------------------------------------------
# CONFIGURE Azure AD Service Principal and Application
#------------------------------------------------------------------------

# Set the password (service principal secret) based on the Kerberos key of the storage account.
$kerbKey1 = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName -ListKerbKey | Where-Object { $_.KeyName -like "kerb1" }
$aadPasswordBuffer = [System.Linq.Enumerable]::Take([System.Convert]::FromBase64String($kerbKey1.Value), 32);
$password = "kk:" + [System.Convert]::ToBase64String($aadPasswordBuffer);

# Connect to Azure AD and retrieve the tenant information
Connect-AzureAD -AzureEnvironmentName $Environment -TenantId $TenantId -Credential $Credential
$azureAdTenantDetail = Get-AzureADTenantDetail;
$azureAdPrimaryDomain = ($azureAdTenantDetail.VerifiedDomains | Where-Object {$_._Default -eq $true}).Name

# Generate the service principal names for the Azure AD service principal
$servicePrincipalNames = New-Object string[] 3
$servicePrincipalNames[0] = 'HTTP/{0}.file.core.windows.net' -f $storageAccountName
$servicePrincipalNames[1] = 'CIFS/{0}.file.core.windows.net' -f $storageAccountName
$servicePrincipalNames[2] = 'HOST/{0}.file.core.windows.net' -f $storageAccountName

# Create an application for the storage account
$application = New-AzureADApplication -DisplayName $storageAccountName -IdentifierUris $servicePrincipalNames -GroupMembershipClaims "All";

# Create a service principal for the storage account 
$servicePrincipal = New-AzureADServicePrincipal -AccountEnabled $true -AppId $application.AppId -ServicePrincipalType "Application";

# Set the password for the storage account's service principal
$Token = ([Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens['AccessToken']).AccessToken
$Uri = ('https://graph.windows.net/{0}/{1}/{2}?api-version=1.6' -f $azureAdPrimaryDomain, 'servicePrincipals', $servicePrincipal.ObjectId)
$json = @'
{
  "passwordCredentials": [
  {
    "customKeyIdentifier": null,
    "endDate": "<STORAGEACCOUNTENDDATE>",
    "value": "<STORAGEACCOUNTPASSWORD>",
    "startDate": "<STORAGEACCOUNTSTARTDATE>"
  }]
}
'@
$now = [DateTime]::UtcNow
$json = $json -replace "<STORAGEACCOUNTSTARTDATE>", $now.AddDays(-1).ToString("s")
  $json = $json -replace "<STORAGEACCOUNTENDDATE>", $now.AddMonths(6).ToString("s")
$json = $json -replace "<STORAGEACCOUNTPASSWORD>", $password
$Headers = @{'authorization' = "Bearer $($Token)"}
try {
  Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method Patch -Headers $Headers -Body $json 
  Write-Host "Success: Password is set for $storageAccountName"
} catch {
  Write-Host $_.Exception.ToString()
  Write-Host "StatusCode: " $_.Exception.Response.StatusCode.value
  Write-Host "StatusDescription: " $_.Exception.Response.StatusDescription
}

# Configure API Permissions for newly created App
$perms = @("14dad69e-099b-42c9-810b-d002981feec1","37f7f235-527c-4136-accd-4a02d197296e", "e1fe6dd8-ba31-4d61-89e7-88639da4683d")
    # 14dad69e-099b-42c9-810b-d002981feec1 = OpenId permissions profile
    # 37f7f235-527c-4136-accd-4a02d197296e = OpenId permissions openid
    # e1fe6dd8-ba31-4d61-89e7-88639da4683d = User permissions User.Read
$appID = $application.AppId
Write-Host "Applying API Permissions to newly created App"
Foreach($perm in $perms){Add-AzADAppPermission -ApplicationId $appID -ApiId "00000003-0000-0000-c000-000000000000" -PermissionId $perm}

# Grant Tenant wide admin consent to App
# https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id={client-id}
Write-Host "Granting Admin Consent for API / Permissions"
$context = Get-AzContext
$TenantId = $context.Tenant.Id
$token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $TenantId, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
$headers = @{
  'Authorization' = 'Bearer ' + $token.AccessToken
  'X-Requested-With'= 'XMLHttpRequest'
  'x-ms-client-request-id'= [guid]::NewGuid()
  'x-ms-correlation-id' = [guid]::NewGuid()}
$url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$AppId/Consent?onBehalfOfAll=true"
Invoke-RestMethod -Uri $url -Headers $headers -Method POST -ErrorAction Stop

# Set the storage account's ActiveDirectoryProperties to support the Shell experience
Write-Host "Configuring current Windows machine to display Azure AD Domain in NTFS permissions window"
$domainInformation = Get-ADDomain
$Domain = $domainInformation.DnsRoot
$domainGuid = $domainInformation.ObjectGUID.ToString()
$domainName = $domainInformation.DnsRoot
$domainSid = $domainInformation.DomainSID.Value
$forestName = $domainInformation.Forest
$netBiosDomainName = $domainInformation.DnsRoot
$azureStorageSid = $domainSid + "-123454321";

Write-Verbose "Setting AD properties on $storageAccountName in $resourceGroupName : `
        EnableActiveDirectoryDomainServicesForFile=$true, ActiveDirectoryDomainName=$domainName, `
        ActiveDirectoryNetBiosDomainName=$netBiosDomainName, ActiveDirectoryForestName=$($domainInformation.Forest) `
        ActiveDirectoryDomainGuid=$domainGuid, ActiveDirectoryDomainSid=$domainSid, `
        ActiveDirectoryAzureStorageSid=$azureStorageSid"

$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $subscriptionId, $resourceGroupName, $storageAccountName);

$json=
    @{
        properties=
            @{azureFilesIdentityBasedAuthentication=
                @{directoryServiceOptions="AADKERB";
                    activeDirectoryProperties=@{domainName="$($domainName)";
                                                netBiosDomainName="$($netBiosDomainName)";
                                                forestName="$($forestName)";
                                                domainGuid="$($domainGuid)";
                                                domainSid="$($domainSid)";
                                                azureStorageSid="$($azureStorageSid)"}
                }
            }
    };  

$json = $json | ConvertTo-Json -Depth 99

$token = $(Get-AzAccessToken).Token
$headers = @{ Authorization="Bearer $token" }

try {
    Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json
} catch {
    Write-Host $_.Exception.ToString()
    Write-Host "Error setting Storage Account AD properties.  StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "Error setting Storage Account AD properties.  StatusDescription:" $_.Exception.Response.StatusDescription
    Write-Error -Message "Caught exception setting Storage Account AD properties: $_" -ErrorAction Stop
}

Write-Host "Finished!" -ForegroundColor Green