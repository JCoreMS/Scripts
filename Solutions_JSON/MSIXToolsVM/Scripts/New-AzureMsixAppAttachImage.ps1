# Prerequisites
# Ensure your code signing certificate is available in an Azure Key Vault
# Stage the application and its associated conversion XML file in an Azure Storage Account Container
# Established an SMB share for the MSIX App Attach images

Param(

    [parameter(Mandatory)]
    [string]$FileShareName,

    [parameter(Mandatory)]
    [string]$StorageAccountKey,

    [parameter(Mandatory)]
    [string]$StorageAccountName
)
$Error.Clear()
# Turn off auto updates
reg add HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /t REG_DWORD /d 0 /f
Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Automatic app update" /Disable
Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable

# Disable Content Delivery auto download apps that they want to promote to users:
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug /v ContentDeliveryAllowedOverride /t REG_DWORD /d 0x2 /f

#Make Local MSIX Dir for tools
New-Item -Path "C:\MSIX" -ItemType Directory

# Downloads and installs the MSIX Packaging Tool
Invoke-WebRequest -Uri "https://download.microsoft.com/download/d/9/7/d9707be8-06db-4b13-a992-48666aad8b78/91b9474c34904fe39de2b66827a93267.msixbundle" -OutFile "C:\MSIX\MsixPackagingTool.msixbundle"
Add-AppPackage -Path "C:\MSIX\MsixPackagingTool.msixbundle"

# Downloads and installs the PFSTooling Tool
Invoke-WebRequest -URI "https://www.tmurgent.com/APPV/Tools/PsfTooling/PsfTooling-x64-5.0.0.0.msix" -OutFile "C:\MSIX\PsfTooling-x64-5.0.0.0.msix"
Add-AppPackage -Path "C:\MSIX\PsfTooling/PsfTooling-x64-5.0.0.0.msix"

# Downloads and extracts the MSIX Manager Tool
Invoke-WebRequest -URI "https://aka.ms/msixmgr" -OutFile "C:\MSIX\MSIXmgrTool.zip"
Expand-Archive -Path "C:\MSIX\MSIXmgrTool.zip" -DestinationPath "C:\MSIX\msixmgr"

# Download Script to convert MSIX to VHD


# Stops the Shell HW Detection service to prevent the format disk popup
Stop-Service -Name ShellHWDetection -Force

# Map Drive for MSIX Share
cmd.exe /C "cmdkey /add:`"$StorageAccountName.file.core.windows.net`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""
New-PSDrive -Name M -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist

If($Error){Return $Error}