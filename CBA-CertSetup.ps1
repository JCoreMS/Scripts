
$CertFolderLocation = "C:\Temp\cert"
$CertFileName = "Certificates_PKCS7_v5.9_DoD.der.p7b"

Install-Module -Name AzureAD –RequiredVersion 2.0.0.33
Import-Module AzureAD
Connect-AzureAD

# Use Certutil to dump P7B to individual Cert files
If(!(Test-Path -PathType Container $CertFolderLocation\CertDump)) {
    New-Item -ItemType Directory -Path $CertFolderLocation\CertDump 
}
Set-Location -Path $CertFolderLocation\CertDump
& certutil -split -dump $CertFolderLocation\$CertfileName  # Dumps each as CRT files

# Rename from CRT to CER
Get-ChildItem -Path $CertFolderLocation\CertDump\* -Include *.crt | Rename-Item -NewName {$_.Name -replace '.crt','.cer'}

$Certs = Get-ChildItem -Path $CertFolderLocation\CertDump\* -Include *.cer

$file = "C:\Users\jcore.NORTHAMERICA\Downloads\CBATesting\DODRootCA3.cer"
$file = 
$file = "C:\Users\jcore.NORTHAMERICA\Downloads\CBATesting\DODIDCA64.cer"
$file = "C:\Users\jcore.NORTHAMERICA\Downloads\CBATesting\USDoDCCEBInteropRootCA2.cer"

# Loop each file in dir
Foreach($file in $Certs){
    $cert = Get-Content -Encoding byte $file
    $new_ca = New-Object -TypeName Microsoft.Open.AzureAD.Model.CertificateAuthorityInformation
    $new_ca.AuthorityType = 0
    $new_ca.TrustedCertificate = $cert
    #$new_ca.crlDistributionPoint = "http://crl.defence.gov.au/pki/crl/ADIOCA.crl"
    New-AzureADTrustedCertificateAuthority -CertificateAuthorityInformation $new_ca
}

$certfile = $Certs[0]
$certfile
# Add
$cert=Get-Content -Encoding byte $certfile
$new_ca=New-Object -TypeName Microsoft.Open.AzureAD.Model.CertificateAuthorityInformation
$new_ca.AuthorityType=0
$new_ca.TrustedCertificate=$cert
$new_ca.crlDistributionPoint="http://crl.disa.mil/crl/"
New-AzureADTrustedCertificateAuthority -CertificateAuthorityInformation $new_ca

# Remove
$c=Get-AzureADTrustedCertificateAuthority
Remove-AzureADTrustedCertificateAuthority -CertificateAuthorityInformation $c[2]

# Modify
$c=Get-AzureADTrustedCertificateAuthority
$c[0].AuthorityType=1
Set-AzureADTrustedCertificateAuthority -CertificateAuthorityInformation $c[0]

