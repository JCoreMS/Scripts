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
    [string]$StorageAccountName,

    [parameter(Mandatory)]
    [string]$VMUserName,

    [parameter(Mandatory)]
    [string]$VMUserPassword
)

$VMUserPassword = ConvertTo-SecureString -String $VMUserPassword -AsPlainText -Force
$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $VMUserName, $VMUserPassword

Invoke-Command -scriptblock {

    $Error.Clear()

    #Make Local MSIX Dir for tools
    New-Item -Path "C:\MSIX" -ItemType Directory
    New-Item -Path "C:\MSIX\Packages" -ItemType Directory
    New-Item -Path "C:\MSIX\Scripts" -ItemType Directory

    # Create Log file for output and troublehsooting
    $Log = "C:\MSIX\PostConfig.log"
    New-Item $Log
    Get-Date | Out-file $Log

    # Turn off auto updates
    "Turn Off Auto Updates via Registry and Disable Scheduled Tasks" | Out-File $Log
    reg add HKLM\Software\Policies\Microsoft\WindowsStore /v AutoDownload /t REG_DWORD /d 0 /f
    Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Automatic app update" /Disable
    Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Disable Content Delivery auto download apps that they want to promote to users:
    "Disable Content Delivery auto download apps" | Out-File $Log
    reg add HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f
    reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug /v ContentDeliveryAllowedOverride /t REG_DWORD /d 0x2 /f
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Downloads and installs the MSIX Packaging Tool
    "Downloading and installing MSIX Packaging Tool" | Out-File $Log
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/d/9/7/d9707be8-06db-4b13-a992-48666aad8b78/91b9474c34904fe39de2b66827a93267.msixbundle" -OutFile "C:\MSIX\MsixPackagingTool.msixbundle"
    Add-AppPackage -Path "C:\MSIX\MsixPackagingTool.msixbundle"
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Downloads and installs the PFSTooling Tool
    Invoke-WebRequest -URI "https://www.tmurgent.com/APPV/Tools/PsfTooling/PsfTooling-x64-5.0.0.0.msix" -OutFile "C:\MSIX\PsfTooling-x64-5.0.0.0.msix"
    Add-AppPackage -Path "C:\MSIX\PsfTooling-x64-5.0.0.0.msix"
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Downloads and extracts the MSIX Manager Tool
    "Downloading and Extracting the MSIX Manager Command Line tool" | Out-File $Log
    Invoke-WebRequest -URI "https://aka.ms/msixmgr" -OutFile "C:\MSIX\MSIXmgrTool.zip"
    Expand-Archive -Path "C:\MSIX\MSIXmgrTool.zip" -DestinationPath "C:\MSIX\msixmgr"
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Download Script to convert MSIX to VHD
    "Downloading MSIX to VHD Script" | Out-File $Log
    Invoke-WebRequest -URI "https://raw.githubusercontent.com/JCoreMS/DeployMSIXVM/main/Scripts/ConvertMSIX2VHD.ps1" -OutFile "C:\MSIX\Scripts\ConvertMSIX2VHD.ps1"
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Stops the Shell HW Detection service to prevent the format disk popup
    "Stoping Plug and Play Service and setting to disabled" | Out-file $Log
    Stop-Service -Name ShellHWDetection -Force
    set-service -Name ShellHWDetection -StartupType Disabled
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    # Map Drive for MSIX Share
    "Mapping MSIX Share to M:"
    cmd.exe /C "cmdkey /add:`"$StorageAccountName.file.core.windows.net`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""
    New-PSDrive -Name M -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist
    If($Error.Count -eq 0){".... COMPLETED!" | Out-File $Log}
    Else{"-----ERROR-----`n$Error" | Out-File $Log; $Error.Clear()}

    "-------------------------- END SCRIPT RUN ------------------------" | Out-File $Log
    
} -Credential $Creds